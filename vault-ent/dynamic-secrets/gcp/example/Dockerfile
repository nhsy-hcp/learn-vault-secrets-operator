# Use the official Python 3.8 slim image as the base image
FROM python:3.9-slim

ARG PROJECT_ID

# Set the working directory within the container
WORKDIR /app

# Copy the necessary files and directories into the container
COPY src /app
COPY requirements.txt  /app/

# Upgrade pip and install Python dependencies
RUN pip3 install --upgrade pip && pip install --no-cache-dir -r requirements.txt

# Expose port 5000 for the Flask application
EXPOSE 5000

# Define the command to run the Flask application using Gunicorn
CMD ["gunicorn", "app:app", "-b", "0.0.0.0:5000", "-w", "1"]