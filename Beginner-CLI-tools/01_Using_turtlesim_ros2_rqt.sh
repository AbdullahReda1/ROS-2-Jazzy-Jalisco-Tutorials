#!/usr/bin/bash
# Uncomment the following lines to install the turtlesim package if you haven't already
# sudo apt update
# sudo apt install ros-jazzy-turtlesim


# List the executables in the turtlesim package
ros2 pkg executables turtlesim

# Adding new line after command executing
echo -e

# Run turtlesim_node in a new terminal
# gnome-terminal: Launches a new GNOME Terminal window
# --            : Separates options from the command to run
# bash -c       : Tells bash to execute the command string `-c` that follows
# ;             : Separates commands in the command string
# exec bash     : Replaces the current shell with bash, keeping the terminal open after the command finishes
gnome-terminal -- bash -c "ros2 run turtlesim turtlesim_node; exec bash"

# Run turtle_teleop_key in a new terminal
gnome-terminal -- bash -c "ros2 run turtlesim turtle_teleop_key; exec bash"

# Run the list commands in a new terminal
echo "📡 Nodes:"
ros2 node list
echo

echo "📡 Topics:"
ros2 topic list
echo

echo "📡 Services:"
ros2 service list
echo

echo "📡 Actions:"
ros2 action list
echo


# Uncomment the following lines to install rqt and rqt plugins if you haven't already
# sudo apt update
# sudo apt install '~nros-jazzy-rqt*'

# Run rqt in a new terminal
gnome-terminal -- bash -c "rqt; exec bash"

# 1. In rqt use the "Plugins" menu then select "Service"  then "Service Caller" then select the "/spawn" service and click "Call Service" 
#    to spawn a new turtle in the turtlesim window after choosing the x, y, theta values and the name string for the new turtle.
# 2. Try set_pen service to change the pen color of the turtle by selecting the "/turtle1/set_pen" service and click "Call Service" 
#    then set the r, g, b values with 0-255 to change the pen color of turtle1.

# Wait a bit to ensure turtlesim is running
sleep 2

# Before remapping command, spawn a new turtle2 using the /spawn service using CLI -Here only to move forward in the tutorial-.
ros2 service call /spawn turtlesim/srv/Spawn "{x: 1.0, y: 1.0, theta: 0.0, name: 'turtle2'}"

# Run turtle_teleop_key with remapping in a new terminal to control turtle2 with the same teleop keys
gnome-terminal -- bash -c "ros2 run turtlesim turtle_teleop_key --ros-args --remap turtle1/cmd_vel:=turtle2/cmd_vel; exec bash"