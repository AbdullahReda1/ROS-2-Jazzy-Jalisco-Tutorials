#!/usr/bin/bash

###############################################
# ROS 2 SERVICES - PRACTICAL + EXPLANATION
# ---------------------------------------------
# This script walks through ROS 2 Services
# using turtlesim + CLI tools.
#
# Services = Request / Response communication
# (NOT continuous like topics)
###############################################


##############################
# 0) (Optional) Install packages
##############################
# sudo apt update
# sudo apt install ros-jazzy-turtlesim


##############################
# 1) Start core nodes
##############################

# Run turtlesim node (service SERVER)
gnome-terminal -- bash -c "ros2 run turtlesim turtlesim_node; exec bash"

# Run teleop node (client interacting with turtlesim)
gnome-terminal -- bash -c "ros2 run turtlesim turtle_teleop_key; exec bash"

# Wait for nodes to fully initialize
sleep 2


##############################
# 2) List all active services
##############################

echo "📡 Available Services:"
ros2 service list
echo

# 👉 Insight:
# Services like:
# /clear, /spawn, /kill ...
# are provided by turtlesim node


##############################
# 3) Show services WITH types
##############################

echo "📡 Services with Types:"
# ros2 service list -t
ros2 service list --show-types
echo

# 👉 Insight:
# Each service has a TYPE (interface)
# Example:
# /spawn → turtlesim/srv/Spawn
# /clear → std_srvs/srv/Empty


##############################
# 4) Inspect a specific service type
##############################

echo "🔍 Type of /clear:"
ros2 service type /clear
echo

# 👉 std_srvs/srv/Empty means:
# No request data, no response data


##############################
# 5) Detailed service info
##############################

echo "📊 Info about /clear:"
ros2 service info /clear
echo

# 👉 Shows:
# - Type
# - Number of clients
# - Number of servers


##############################
# 6) Find services by type
##############################

echo "🔎 Services using Empty type:"
ros2 service find std_srvs/srv/Empty
echo

# 👉 Useful when:
# You know TYPE but not service names


##############################
# 7) Inspect interface structure
##############################

echo "🧠 Interface of Spawn service:"
ros2 interface show turtlesim/srv/Spawn
echo

# 👉 IMPORTANT CONCEPT:
# Services = 2 parts:
# Request (input)
# ---
# Response (output)
#
# Spawn request:
# x, y, theta, name


##############################
# 8) Call simple service (NO args)
##############################

echo "🧹 Clearing screen using service:"
ros2 service call /clear std_srvs/srv/Empty
echo

# 👉 Effect:
# Clears all turtle drawings


##############################
# 9) Call service WITH arguments
##############################

echo "🐢 Spawning new turtle:"
ros2 service call /spawn turtlesim/srv/Spawn "{x: 2.0, y: 2.0, theta: 0.0, name: ''}"
echo

# 👉 YAML FORMAT:
# "{key: value, key: value}"
#
# 👉 name: '' means auto-generate name
# Expected: turtle2 appears


##############################
# 10) ros2 service echo (INTROSPECTION)
##############################

echo "🔬 Starting service introspection demo..."

# Run introspection demo (creates service client/server)
gnome-terminal -- bash -c \
"ros2 launch demo_nodes_cpp introspect_services_launch.py; exec bash"

# Give time for nodes to start
sleep 3


########################################
# Enable introspection on BOTH sides
########################################

echo "⚙️ Enabling introspection..."

ros2 param set /introspection_service service_configure_introspection contents
ros2 param set /introspection_client client_configure_introspection contents

echo


########################################
# Echo the service communication
########################################

echo "📡 Echoing service communication (/add_two_ints):"

gnome-terminal -- bash -c \
"ros2 service echo --flow-style /add_two_ints; exec bash"


########################################
# Trigger a request manually
########################################

echo "🚀 Sending request to trigger communication..."

ros2 service call /add_two_ints example_interfaces/srv/AddTwoInts "{a: 2, b: 3}"

echo


########################################
# Explanation (VERY IMPORTANT)
########################################

echo "
🧠 What you are seeing:

REQUEST_SENT        → Client sends request
REQUEST_RECEIVED    → Server receives it
RESPONSE_SENT       → Server sends result
RESPONSE_RECEIVED   → Client gets result

This is the FULL lifecycle of a service call.
"