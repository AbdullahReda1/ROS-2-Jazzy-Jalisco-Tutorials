#!/usr/bin/bash

#########################################################
# ROS 2 LAUNCH (CLI INTRO) - MULTI-NODE EXECUTION
# -------------------------------------------------------
# Launch = start multiple nodes with ONE command
#
# Instead of:
#   opening terminals manually ❌
#
# You use:
#   ros2 launch ✅
#
# Launch files define:
# - nodes
# - namespaces
# - parameters
#########################################################


##############################
# 1) Run Launch File
##############################

echo "🚀 Launching multiple turtlesim nodes..."

gnome-terminal -- bash -c "ros2 launch turtlesim multisim.launch.py; exec bash"

# 👉 This runs a launch file that:
# - starts TWO turtlesim nodes
# - each in a separate namespace
#
# Example:
# /turtlesim1
# /turtlesim2


##############################
# SYSTEM UNDERSTANDING
##############################

echo "
🧠 What just happened:

Instead of:
  ros2 run turtlesim turtlesim_node  (twice)

You executed:
  ros2 launch ...

✔ Launch file started multiple nodes
✔ Each node has its own namespace
✔ Entire system started with ONE command
"

# 👉 Internally:
#
# Launch system:
#   → parses Python launch file
#   → creates processes
#   → applies configuration


##############################
# 2) Inspect running system
##############################

sleep 5  # Wait for nodes to start

echo "📡 Active nodes:"
ros2 node list
echo

# 👉 You will see:
# /turtlesim1/turtlesim
# /turtlesim2/turtlesim

echo "📡 Topics:"
ros2 topic list
echo

# 👉 You will see:
# /parameter_events
# /rosout
# /turtlesim1/turtle1/cmd_vel
# /turtlesim1/turtle1/color_sensor
# /turtlesim1/turtle1/pose
# /turtlesim2/turtle1/cmd_vel
# /turtlesim2/turtle1/color_sensor
# /turtlesim2/turtle1/pose
#
# → Namespaces isolate systems


##############################
# 3) Control turtles independently
##############################

echo "🎮 Controlling turtles independently..."

# Turtle 1 → rotate clockwise
gnome-terminal -- bash -c \
"ros2 topic pub /turtlesim1/turtle1/cmd_vel geometry_msgs/msg/Twist \
\"{linear: {x: 2.0}, angular: {z: 1.8}}\"; exec bash"

# Turtle 2 → rotate counter-clockwise
gnome-terminal -- bash -c \
"ros2 topic pub /turtlesim2/turtle1/cmd_vel geometry_msgs/msg/Twist \
\"{linear: {x: 2.0}, angular: {z: -1.8}}\"; exec bash"

echo "
👉 Observe:
- Two turtles moving differently
- Same node logic, different namespace
"


##############################
# FINAL UNDERSTANDING
##############################

echo "
🧠 LAUNCH MODEL:

Launch File
   ↓
Multiple Nodes
   ↓
Configured System

✔ Launch = system orchestration
✔ Namespaces = system isolation
✔ One command = full system startup
"

echo "
📊 BEFORE vs AFTER:

Before:
  many terminals
  manual commands

After:
  one launch command
  reproducible system
"