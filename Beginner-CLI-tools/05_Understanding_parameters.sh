#!/usr/bin/bash

#########################################################
# ROS 2 PARAMETERS - PRACTICAL + DEEP EXPLANATION
# -------------------------------------------------------
# Parameters = configuration values stored inside nodes
# Think of them as:
# → runtime settings
# → internal state variables
#########################################################


##############################
# 1) Setup (Start Nodes)
##############################

# Start turtlesim node
gnome-terminal -- bash -c \
"ros2 run turtlesim turtlesim_node; exec bash"

# Start teleop node
gnome-terminal -- bash -c \
"ros2 run turtlesim turtle_teleop_key; exec bash"

# Give time for nodes to initialize
sleep 2


##############################
# 2) ros2 param list
##############################

echo "📡 Listing all parameters in the system:"
ros2 param list
echo

# 👉 Understanding:
# Output grouped by node:
# /turtlesim → parameters like background_r/g/b
# /teleop_turtle → parameters like scale_linear
#
# Every node has:
# - its own parameter space
# - its own configuration


##############################
# 3) ros2 param get
##############################

echo "🔍 Getting parameter value (background_g):"
ros2 param get /turtlesim background_g
echo

# 👉 Insight:
# - Shows TYPE + VALUE
# - Here: Integer value (RGB color component)


##############################
# 4) ros2 param set
##############################

echo "🎨 Changing background color (R channel):"
ros2 param set /turtlesim background_r 150
echo

# 👉 Effect:
# - Changes value at runtime
# - turtlesim reacts immediately
#
# ⚠️ IMPORTANT:
# This change is TEMPORARY (not saved)


##############################
# 5) ros2 param dump
##############################

echo "💾 Dumping parameters to file (turtlesim.yaml):"

ros2 param dump /turtlesim > turtlesim.yaml
echo

# 👉 What happens:
# - Saves ALL parameters of /turtlesim
# - Output is YAML file
#
# 👉 This file represents:
# - Full node configuration snapshot


##############################
# 6) ros2 param load
##############################

echo "📂 Loading parameters from file into running node:"

ros2 param load /turtlesim turtlesim.yaml
echo

# 👉 Important Behavior:
# - Some parameters FAIL to load (read-only)
# - Example:
#   qos_overrides.* → cannot change at runtime
#
# 👉 Key Concept:
# Parameters are of two types:
# - dynamic (can change)
# - read-only (fixed after startup)


##############################
# 7) Load parameters at node startup
##############################

echo "🔁 Restarting turtlesim with saved parameters..."

# Stop current turtlesim manually (user action)
echo "⚠️ Please close the turtlesim window manually to continue..."
sleep 5

# Start turtlesim WITH parameter file
gnome-terminal -- bash -c \
"ros2 run turtlesim turtlesim_node --ros-args --params-file turtlesim.yaml; exec bash"
echo

# 👉 Key Insight:
# - At startup → ALL parameters applied (even read-only)
# - This is the CORRECT way to configure systems


##############################
# FINAL UNDERSTANDING
##############################

echo "
🧠 PARAMETERS MODEL:

Node
  └── Parameters (internal config)
        ├── background_r/g/b
        ├── use_sim_time
        └── qos settings

✔ Parameters are NOT communication
✔ They are CONFIGURATION

Topics   → data flow
Services → commands
Parameters → settings
"