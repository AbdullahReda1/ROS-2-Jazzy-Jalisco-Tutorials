#!/usr/bin/bash

#########################################################
# ROS 2 BAG - RECORDING & PLAYBACK (FULL TUTORIAL)
# -------------------------------------------------------
# ros2 bag:
# - Records topics + services into database files
# - Replays them later to reproduce system behavior
#
# This script follows:
# 1) Topics recording
# 2) Topics playback
# 3) Services recording
# 4) Services playback
#########################################################


#########################################################
# ================= SERVICES PART =======================
#########################################################


##############################
# 1) Setup (Service Introspection)
##############################

echo "🔬 Starting service introspection demo..."

gnome-terminal -- bash -c \
"ros2 run demo_nodes_cpp introspection_service --ros-args -p service_configure_introspection:=contents; exec bash"

gnome-terminal -- bash -c \
"ros2 run demo_nodes_cpp introspection_client --ros-args -p client_configure_introspection:=contents; exec bash"

sleep 3


##############################
# Move to working directory
##############################

pathvar=/mnt/ubuntu_data/ROS2/ROS-2-Jazzy-Jalisco-Tutorials/00-Beginner-CLI-tools/09_Recording_playing_back_data/bag_files
cd $pathvar || exit
echo "📁 Current directory: $(pwd)"


##############################
# 2) Check services
##############################

echo "📡 Available services:"
ros2 service list
echo


########################################
# Verify introspection (IMPORTANT STEP)
########################################

echo "📡 Echo service communication:"

gnome-terminal -- bash -c \
"ros2 service echo --flow-style /add_two_ints; exec bash"

echo "
👉 You should see REQUEST/RESPONSE events
"


##############################
# 3) Record service data
##############################

echo "⏺️ Recording service /add_two_ints..."

gnome-terminal -- bash -c \
"ros2 bag record --service /add_two_ints -o srvbag; exec bash"

echo "
👉 Let the client send requests automatically
"


##############################
# 4) Inspect service bag
##############################

echo "📊 Inspect latest bag file manually using:"
echo "ros2 bag info srvbag"
echo


##############################
# 5) Play service data
##############################

sleep 5

echo "
👉 Press CTRL+C to stop recording
⚠️ Stop introspection_client before playback (CTRL+C)
"

sleep 5

echo "▶️ Replaying service requests..."

gnome-terminal -- bash -c "ros2 bag play --publish-service-requests srvbag; exec bash"


########################################
# Optional: Observe replay with echo
########################################

echo "📡 Observe replayed communication:"

gnome-terminal -- bash -c \
"ros2 service echo --flow-style /add_two_ints; exec bash"


#########################################################
# FINAL UNDERSTANDING
#########################################################

echo "
🧠 ROS2 BAG MODEL:

LIVE SYSTEM:
  Nodes → Topics/Services → Data

ros2 bag record:
  → captures data → stores in database

ros2 bag play:
  → re-injects data → reproduces behavior

✔ Topics = continuous replay
✔ Services = request replay
"


echo "
📊 USE CASES:

- Debugging
- Experiment replay
- Dataset generation (VERY IMPORTANT for AI)
- Sharing robotics experiments
"