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
# ================== TOPICS PART ========================
#########################################################


##############################
# 1) Setup (Topics)
##############################

echo "🚀 Starting turtlesim system..."

gnome-terminal -- bash -c \
"ros2 run turtlesim turtlesim_node; exec bash"

gnome-terminal -- bash -c \
"ros2 run turtlesim turtle_teleop_key; exec bash"

sleep 2


##############################
# Create working directory
##############################

pathvar=/mnt/ubuntu_data/ROS2/ROS-2-Jazzy-Jalisco-Tutorials/Beginner-CLI-tools/09_Recording_playing_back_data/bag_files
echo "📁 Creating working directory..."
mkdir -p $pathvar
sleep 1
cd $pathvar || exit
echo "📁 Current directory: $(pwd)"

##############################
# 2) Choose a topic
##############################

echo "📡 Available topics:"
ros2 topic list
echo

echo "🔍 Echo /turtle1/cmd_vel"

gnome-terminal -- bash -c \
"ros2 topic echo /turtle1/cmd_vel; exec bash"


##############################
# 3) Record topics
##############################

########################################
# 3.1 Record single topic
########################################

echo "⏺️ Recording /turtle1/cmd_vel..."

gnome-terminal -- bash -c \
"ros2 bag record /turtle1/cmd_vel; exec bash"

echo "
👉 Move turtle using keyboard
"

sleep 10

echo "
👉 Press CTRL+C in recording terminal to stop
"


########################################
# 3.2 Record multiple topics
########################################

echo "⏺️ Recording multiple topics (cmd_vel + pose)..."

gnome-terminal -- bash -c \
"ros2 bag record -o subset /turtle1/cmd_vel /turtle1/pose; exec bash"

echo "
👉 Move turtle again
"

sleep 10

echo "
👉 Press CTRL+C to stop recording
"


##############################
# 4) Inspect bag data
##############################

echo "📊 Inspecting bag file (subset):"

ros2 bag info subset
echo

# 👉 Shows:
# - duration
# - topics
# - message count
# - types


##############################
# 5) Play topic data
##############################

echo "
⚠️ Stop teleop before playback (CTRL+C in teleop terminal)
"

sleep 5

echo "▶️ Playing back recorded data..."

gnome-terminal -- bash -c "ros2 bag play subset; exec bash"

echo "
👉 Turtle should repeat your recorded motion
"

sleep 2


##############################
# EXTRA: Topic frequency insight
##############################

echo "📈 Measuring pose topic frequency:"

gnome-terminal -- bash -c \
"ros2 topic hz /turtle1/pose; exec bash"