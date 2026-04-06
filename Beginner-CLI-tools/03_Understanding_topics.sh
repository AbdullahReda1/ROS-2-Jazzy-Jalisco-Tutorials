#!/usr/bin/env bash

# ============================================
# 🔧 Source ROS 2 Environment
# ============================================
# This loads all ROS 2 environment variables:
# - PATH for ros2 CLI
# - RMW (DDS middleware)
# - Package paths

# source /opt/ros/jazzy/setup.bash

echo "🚀 ROS 2 Topics Deep Dive (CLI + System Understanding)"
echo

# ============================================
# 🧱 STEP 1: Start Core Nodes
# ============================================

# Start turtlesim node
# This node:
# - Subscribes to velocity commands (/turtle1/cmd_vel)
# - Publishes pose + sensor data
gnome-terminal -- bash -c "
ros2 run turtlesim turtlesim_node;
exec bash"

# Start teleop node
# This node:
# - Reads keyboard input
# - Publishes velocity commands to /turtle1/cmd_vel
gnome-terminal -- bash -c "
ros2 run turtlesim turtle_teleop_key;
exec bash"

# Start rqt_graph node to visualize the ROS graph
# This node:
# - Shows nodes and their connections (topics)
# - Critical for understanding system architecture
gnome-terminal -- bash -c "ros2 run rqt_graph rqt_graph; exec bash"

# Wait until system is ready (better replaced with checks in real systems)
sleep 2

# ============================================
# 🧠 STEP 2: Understand the ROS Graph (Topics)
# ============================================

echo "📡 Listing active topics (communication channels between nodes):"

# Lists all topics currently active in the ROS graph
# Topics = named buses for message passing
ros2 topic list

echo
echo "📡 Listing topics WITH TYPES (CRITICAL):"

# Shows topic + message type
# Type is required so publisher & subscriber agree on data format
ros2 topic list -t

echo

# ============================================
# 🔍 STEP 3: Observe Live Data (Topic Echo)
# ============================================

echo "🔍 Listening to /turtle1/cmd_vel topic..."

# This creates a TEMPORARY NODE:
# /_ros2cli_xxxxx
# It subscribes to the topic and prints messages
gnome-terminal -- bash -c "
ros2 topic echo /turtle1/cmd_vel;
exec bash"

echo "👉 Move the turtle using keyboard to generate messages"
echo

# ============================================
# 📊 STEP 4: Topic Info (Graph Introspection)
# ============================================

echo "📊 Topic info for /turtle1/cmd_vel:"

# Shows:
# - Message type
# - Number of publishers
# - Number of subscribers
ros2 topic info /turtle1/cmd_vel

echo

echo "📊 VERBOSE topic info (VERY IMPORTANT):"

# Shows deep system-level details:
# - Node names
# - QoS policies (reliability, durability, etc.)
# - DDS-level identifiers (GID)
ros2 topic info /turtle1/cmd_vel --verbose

# ros2 topic info /turtle1/cmd_vel -v

echo

# ============================================
# 🧬 STEP 5: Understand Message Structure (IDL)
# ============================================

echo "🧬 Inspecting message definition (IDL): geometry_msgs/msg/Twist"

# This shows the STRUCTURE of the message:
# - linear (Vector3)
# - angular (Vector3)
# This is the contract between nodes
ros2 interface show geometry_msgs/msg/Twist

echo

# ============================================
# 🚀 STEP 6: Publish Data Manually (CLI Publisher)
# ============================================

echo "🚀 Publishing velocity command manually..."

# This creates a temporary publisher node:
# /_ros2cli_xxxxx
# It sends velocity commands directly to turtlesim

gnome-terminal -- bash -c "

ros2 topic pub /turtle1/cmd_vel geometry_msgs/msg/Twist \
\"{linear: {x: 2.0, y: 0.0, z: 0.0}, angular: {z: 1.8}}\";

exec bash"

echo "👉 Observe turtle movement (continuous publishing)"
echo

# ============================================
# ⚡ STEP 7: Publish Once (Controlled Command)
# ============================================

echo "⚡ Publishing ONE message only..."

# --once: send a single message then exit
# -w 1: wait for at least 1 subscriber
ros2 topic pub --once -w 1 /turtle1/cmd_vel geometry_msgs/msg/Twist \
"{linear: {x: 1.0}, angular: {z: 0.5}}"

echo

# ============================================
# 📈 STEP 8: Measure Topic Frequency
# ============================================

echo "📈 Measuring publishing rate of /turtle1/pose..."

# Measures how fast messages are received
# Useful for:
# - real-time systems
# - debugging performance
gnome-terminal -- bash -c "
ros2 topic hz /turtle1/pose;
exec bash"

echo

# ============================================
# 📦 STEP 9: Measure Bandwidth
# ============================================

echo "📦 Measuring bandwidth of /turtle1/pose..."

# Shows:
# - data rate (KB/s)
# - message size
gnome-terminal -- bash -c "
ros2 topic bw /turtle1/pose;
exec bash"

echo

# ============================================
# 🔎 STEP 10: Find Topics by Type
# ============================================

echo "🔎 Finding topics of type geometry_msgs/msg/Twist..."

# Reverse lookup:
# Instead of topic → type
# You do: type → topic
ros2 topic find geometry_msgs/msg/Twist

echo

# ============================================
# 🧠 FINAL UNDERSTANDING
# ============================================

echo "🧠 SYSTEM MODEL:"
echo "teleop_turtle (Publisher) → /turtle1/cmd_vel → turtlesim (Subscriber)"
echo
echo "turtlesim (Publisher) → /turtle1/pose → your CLI tools (Subscribers)"
echo