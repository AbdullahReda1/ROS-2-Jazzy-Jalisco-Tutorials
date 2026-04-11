#!/usr/bin/bash

#########################################################
# ROS 2 RQT CONSOLE - LOGGING + DEBUGGING TOOL
# -------------------------------------------------------
# rqt_console = GUI tool to visualize ROS 2 logs
#
# Logs = messages from nodes about:
# - state
# - warnings
# - errors
#
# This script reproduces:
# - log generation
# - log filtering behavior
#########################################################


##############################
# 1) Setup
##############################

# Start rqt_console (log viewer)
gnome-terminal -- bash -c \
"ros2 run rqt_console rqt_console; exec bash"

# Start turtlesim node (log producer)
gnome-terminal -- bash -c \
"ros2 run turtlesim turtlesim_node; exec bash"

sleep 2

echo "
🧠 rqt_console UI:

- Top: log messages stream
- Middle: severity filters (INFO/WARN/ERROR...)
- Bottom: highlight filters (search text)

You are now observing logs from /turtlesim
"


##############################
# 2) Generate log messages
##############################

echo "🚀 Generating WARN logs (forcing turtle to hit wall)..."

# This continuously publishes velocity
# → turtle hits wall
# → turtlesim generates WARN logs

gnome-terminal -- bash -c \
"ros2 topic pub -r 1 /turtle1/cmd_vel geometry_msgs/msg/Twist \
\"{linear: {x: 2.0, y: 0.0, z: 0.0}, angular: {z: 0.0}}\"; exec bash"

echo "
👉 Observe in rqt_console:
Repeated WARN messages (turtle hitting wall)

Press CTRL+C in that terminal to stop publishing
"


##############################
# 3) Logger levels
##############################

echo "
📊 ROS 2 Logging Levels (by severity):

1. FATAL   → system failure
2. ERROR   → major issue
3. WARN    → unexpected behavior
4. INFO    → normal status (default)
5. DEBUG   → detailed internal steps
"

# 👉 Important rule:
# You see ONLY:
# current level + higher severity


##############################
# 3.1) Change logger level
##############################

echo "⚙️ Restarting turtlesim with WARN log level..."

# User should close previous turtlesim manually
echo "⚠️ Close previous turtlesim window and rqt_console window manually..."
sleep 10

gnome-terminal -- bash -c "ros2 run rqt_console rqt_console; exec bash"

gnome-terminal -- bash -c \
"ros2 run turtlesim turtlesim_node --ros-args --log-level WARN; exec bash"

echo "
👉 Effect:
- INFO logs are hidden
- Only WARN, ERROR, FATAL are visible

Observe in rqt_console difference
"


##############################
# FINAL UNDERSTANDING
##############################

echo "
🧠 LOGGING MODEL:

Node → produces logs → /rosout topic → rqt_console

✔ Logs are just messages (like topics)
✔ rqt_console subscribes to them

📊 Usage:
- Debugging
- Monitoring
- Error tracing
"