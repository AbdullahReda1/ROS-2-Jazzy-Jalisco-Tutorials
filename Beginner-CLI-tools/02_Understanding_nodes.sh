#!/usr/bin/env bash

# ==============================
# 🔧 Source ROS 2 Environment
# ==============================
#source /opt/ros/jazzy/setup.bash

echo "🚀 ROS 2 Nodes Tutorial (CLI Version)"
echo

# ==============================
# 📦 Step 1: Run turtlesim node
# ==============================
echo "▶️ Running turtlesim_node..."
gnome-terminal -- bash -c "ros2 run turtlesim turtlesim_node; exec bash"

# ==============================
# 📡 Step 2: List nodes
# ==============================
echo "⏳ Waiting for node to start..."
sleep 2

echo "📡 Active Nodes:"
ros2 node list
echo

# ==============================
# 🎮 Step 3: Run teleop node
# ==============================
echo "▶️ Running turtle_teleop_key..."
gnome-terminal -- bash -c "ros2 run turtlesim turtle_teleop_key; exec bash"

sleep 2

echo "📡 Nodes after starting teleop:"
ros2 node list
echo

# ==============================
# 🔁 Step 4: Remap node name
# ==============================
echo "▶️ Running another turtlesim with remapped node name..."
gnome-terminal -- bash -c "ros2 run turtlesim turtlesim_node --ros-args --remap __node:=my_turtle; exec bash"

sleep 2

echo "📡 Nodes after remapping:"
ros2 node list
echo

# ==============================
# 🔍 Step 5: Node info
# ==============================
echo "🔍 Inspecting node: /my_turtle"
ros2 node info /my_turtle
echo

echo "🔍 Inspecting node: /teleop_turtle"
ros2 node info /teleop_turtle
echo

# ==============================
# 📡 Extra: Show full system state
# ==============================
echo "📡 Topics:"
ros2 topic list
echo

echo "📡 Services:"
ros2 service list
echo

echo "📡 Actions:"
ros2 action list
echo