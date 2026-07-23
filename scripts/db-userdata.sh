#!/bin/bash
dnf update -y
dnf install -y nc netcat

# Create mock TCP listeners on 3306 (MySQL) and 5432 (PostgreSQL)
while true; do
  echo -e "HTTP/1.1 200 OK\n\n{\"status\":\"db_healthy\",\"engine\":\"mysql\",\"connections\":8}" | nc -l -p 3306
done &

while true; do
  echo -e "HTTP/1.1 200 OK\n\n{\"status\":\"db_healthy\",\"engine\":\"postgres\",\"connections\":4}" | nc -l -p 5432
done &
