# Troubleshooting Log — Lessons from Deployment & Debugging

This log documents real incidents encountered while building and debugging
this project, in the order they happened. Each entry follows the same
format: what broke, what it looked like, the actual root cause, the fix, and
the underlying lesson. Kept here as both a personal reference and whomever wants to read it.

---

## 1. GitHub push ≠ deployment

**Symptom:** 
Pushed updated `server.js` to GitHub, restarted EC2 instances,
old code still served.

**Root cause:** 
Nothing in the AWS deployment watches the GitHub repo.
The only place running code actually lives is baked into the Launch
Template's user-data as a base64 blob, set at instance launch time.
Restarting an instance does not re-run user-data. That only works on
first boot.

**Fix:** 
Rebuilt the user-data script with the new code, pushed a new Launch
Template version, set it as default, then ran
`aws autoscaling start-instance-refresh` to actually replace running
instances.

**Lesson:** 
A repo and a deployment are two separate systems until a
CI/CD pipeline connects them. This is exactly the gap CI/CD tooling exists.
I see the strength of the pipelines now after spent 6ish hours of troubleshooting with the help of AI.


---

## 2. Netcat placeholder never actually ran — silently, for the entire project

**Symptom:** 
DB connectivity check returned `ECONNREFUSED` from the app
tier, despite security groups looking correct on paper.

**Root cause:** 
The original `db-userdata.sh` tried to install `nc` and
`netcat` via `dnf`, but Amazon Linux 2023 packages netcat under a different
name (`nmap-ncat`). The install did nothing useful, and the `while true; do nc -l -p 3306 ...; done`
 loop failed 50+ times per second in the background from the very first boot — with zero visible error
anywhere except deep in `/var/log/cloud-init-output.log`.

**Fix:** 
Installed the correctly-named package, and upgraded to
a real MariaDB instance instead of a placeholder listener.

**Lesson:** 
A `while true` loop around a failing command doesn't fail
visibly.  It just fails forever, quietly. User-data scripts should check
exit codes and fail (or log clearly) rather than assume install
commands succeeded. This can save up hours or searching in the wrong direction.
Next time I will setup an actual DB instead of a placeholder listener.

---

## 3. `ECONNREFUSED` vs. timeout — different failures, different layers

**Symptom:** 
A raw TCP check returned `ECONNREFUSED` rather than timing out.

**Root cause / lesson:** 
This distinction turned out to be genuinely diagnostic. 
A security group drops denied packets. The client just times out with no response.
 `ECONNREFUSED` means the packet **reached** the destination host and got an active TCP RST back, 
which only happens if nothing is listening on that port, or a local firewall on the
destination is actively rejecting. This one distinction ruled out routing
and security groups and pointed at the host itself.
Highlighting again the importance of the basic knowledge of how the internet works.

---

## 4. Installing packages on an intentionally isolated instance

**Symptom:** 
`dnf install -y mariadb105-server` hung indefinitely with no
progress, no error, no ETA.

**Root cause:** 
The data-tier route table has no default route to the
internet, by design. This is the core isolation control of the whole
architecture. `dnf` had no path to AWS's package repositories at all, so
the connection just sat open with no response.

**Fix:** 
Added a temporary `0.0.0.0/0 → NAT Gateway` route to the data
route table, ran the install, then immediately deleted the route afterward
to restore full isolation.

**Lesson:** 
This is a documented, legitimate pattern ("ephemeral NAT
routes") for patching genuinely air-gapped infrastructure.
The isolation working exactly as designed, at an inconvenient moment, is
still doing it's job. Also didn't know this procedure until I looked it up. 

---

## 5. Recovering an instance with no SSH key pair — EBS volume swap

**Symptom:** 
Neither the bastion nor the DB instance had a key pair
assigned at launch (`KeyName: null`), and SSM couldn't reach the DB
instance either, since it lives in the isolated subnet with no route to
Systems Manager's endpoints.

**Fix:** 
Standard "break-glass" recovery. Stop the instance, detach its
root EBS volume, attach it to a *different* instance that's still
reachable, mount it, manually inject a public key into the mounted
volume's `authorized_keys`, unmount, reattach to the original instance,
and restart it.

**Lesson:** 
Double checking before launch for the keys in case after launch it needs
fixing. After the correction is done deleting the key to it. 

**Sub-lessons from this one procedure alone:**
- **UUID collisions on XFS:** 
mounting a volume cloned from the same base
  AMI as the host's own root volume can fail with a generic "wrong fs
  type" error that has nothing to do with the actual filesystem type.
  The fix is the `nouuid` mount option, which tells the kernel not to
  enforce filesystem UUID uniqueness for that mount.

- **`sudo echo ... >> file` doesn't do what it looks like it does.** 
The `>>` redirect happens in the *current* (unprivileged) shell before
  `sudo` ever touches the `echo` command — so it fails on any file the
  current user can't write to. The fix is wrapping the whole pipeline in
  `sudo bash -c '...'` so the redirect itself runs as root.

- **Nitro-based instances name attached volumes differently.** `/dev/sdf`
  is only the *requested* name; Nitro instance types (t3, t3.micro
  included) surface it as `/dev/nvme*` instead — always confirm with
  `lsblk` after attaching, never assume.

- **Always confirm the real UID before setting ownership.** `ec2-user`
  happened to be UID 1000 here, but assuming that without checking
  `/etc/passwd` on the mounted volume is exactly the kind of shortcut that
 breaks permissions.

**Lesson:**
This was way above my current knowledge level I relied heavily on AI troubleshoot 
and guide through of the procedure. 
---

## 6. SSM has boundaries too — it's not a universal backdoor

**Symptom:** 
`ssm:StartSession` failed with `AccessDeniedException` when
run *from inside* an already-open SSM session on another instance.

**Root cause:** 
Commands run inside an SSM session use that instance's own
IAM role, not the operator's local credentials. The app-tier instance's
role was correctly scoped to *receive* sessions, not to *initiate* them
into other instances — which is the right, least-privilege behavior. If it
could, a compromised app-tier instance could pivot straight into the
database tier via SSM.

**Separately:** 
SSM could not reach the DB instance at all, regardless of
IAM permissions, because the isolated subnet has no route to Systems
Manager's endpoints — the same isolation from incident #4, showing up in a
different tool.

**Lesson:** 
IAM correctness and network reachability are two independent
requirements. Fixing one doesn't imply the other, and a permission error
can sometimes mask what's really a network problem underneath.

---

## 7. WSL's ssh-agent doesn't persist across terminal sessions

**Symptom:** 
`ssh -A` kept failing with "Permission denied," even after a
key had apparently been added successfully.

**Root cause:** 
`ssh-add -l` revealed "Could not open a connection to your
authentication agent". There was no agent running at all in that shell
session, so the earlier `ssh-add` had nothing to actually load the key
into.

**Fix:** 
`eval "$(ssh-agent -s)"` before `ssh-add`, every new WSL terminal.

**Lesson:** 
A WSL specific lesson that I learnt the hard way. Knowing the right tool to
use in certain times can save up a lot of time. 
But to be clear I did not know this could be a problem. 
---

## 8. Two lab-leftover resources billing quietly for two days

**Found during a full AWS audit:** 
An EC2 instance (`db-server-1a`), an active NAT Gateway, and a separate Application Load Balancer
(`app-alb`). All in an entirely different VPC left over from the
lab exercises this project was built on top of, still billing since before
this project even started.

**Lesson:** 
Resource cleanup after a lab isn't optional, and "I don't
recognize this in my account" is worth investigating immediately, not
assuming it's fine. A systematic audit script (see `aws-audit.sh`) caught
this in minutes. Spot-checking individual resources by hand would not have.
Also impementing a daily check or cleanup session for any unused resources. 

---

## 9. A security group rule drifted open during live troubleshooting

**Found during the same audit:** the bastion's security group allowed SSH
from `0.0.0.0/0`. Instead of a single trusted IP, directly contradicting 
the project's own documented least-privilege design.

**Root cause:** 
Almost certainly an `authorize-security-group-ingress`
command run without the `/32` CIDR suffix during the pressure of
mid-session key-pair troubleshooting.

**Lesson:** 
Any command that touches a security group deserves an
immediate `describe-security-groups` check afterward. The same reflex as
checking `describe-instances` after any EC2 action. This is cheap
insurance that would have caught the mistake the moment it happened,
instead of hours later during a full audit.


---

## 10. Stopping ASG-managed instances directly fights the ASG

**Context:** 
Shutting everything down for a weekend to avoid unnecessary
billing.

**Root cause avoided:** 
Directly stopping an ASG-managed instance makes its health check fail,
which left unattended  would cause the ASG to terminate the "unhealthy" 
instance and launch a replacement to maintain desired capacity. 
The exact opposite of the intended cost savings.

**Fix:** 
`aws autoscaling suspend-processes` 
(specifically `Launch`,`HealthCheck`, `ReplaceUnhealthy`, `AlarmNotification`, `ScheduledActions`)
*before* stopping any instance, and resume only *after* instances are confirmed back up on restart and not before.

**Lesson:** 
An Auto Scaling Group is an active system with its own
opinions, not a passive label on a group of instances. Any manual action
on ASG members needs to account for what the ASG will try to do in
response.

---

## Summary — what this session actually taught
The base knowledge of the relation between security groups, instances,
route tables, etc., is crusial to do an efficient troubleshooting. 
Understanding IAM roles vs. network reachability as separate failure
domains, respecting (and safely working around) intentional isolation
rather than fighting it, and treating infrastructure automation (ASGs,
SSM, security groups) as active systems that react to changes rather than
static configuration. None of these were textbook exercises every one
came from the building the project. 