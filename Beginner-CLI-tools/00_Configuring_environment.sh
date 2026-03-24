# Load the ROS 2 Jazzy environment into the current shell session.
source /opt/ros/jazzy/setup.bash

# Make the ROS 2 environment load automatically in future Bash sessions.
# Note: Uncomment the line below to enable this behavior if it the first time to prevent duplicate entries in .bashrc.
# echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc

# Show the current .bashrc contents so we can confirm the new line was appended.
cat ~/.bashrc

# Display environment variables related to ROS that are currently available.
printenv | grep -i ros

# Set the DDS/ROS domain ID for this shell session.
export ROS_DOMAIN_ID=0

# Persist the ROS domain ID so future Bash sessions use the same value.
# Note: Uncomment the line below to enable this behavior if it the first time to prevent duplicate entries in .bashrc.
# echo "export ROS_DOMAIN_ID=0" >> ~/.bashrc

# Verify the ROS-related environment again, including the domain ID we just set.
printenv | grep -i ros
