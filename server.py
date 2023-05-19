from pythonosc import osc_message_builder
from pythonosc import udp_client
import socket

# setup UDP server
UDP_IP = "0.0.0.0"
UDP_PORT = 8888
sock = socket.socket(socket.AF_INET, # Internet
                     socket.SOCK_DGRAM) # UDP
sock.bind((UDP_IP, UDP_PORT))

# Set a timeout so the socket does not block indefinitely
sock.settimeout(1.0)  # timeout in seconds

# setup OSC client
client = udp_client.SimpleUDPClient("127.0.0.1", 57120)  # IP and port of SuperCollider

try:
    while True:
        try:
            data, addr = sock.recvfrom(1024) # buffer size is 1024 bytes
            value = float(data.decode("utf-8"))
            print("Received value:", value)
            client.send_message("/sensor", value)
        except socket.timeout:
            continue
except KeyboardInterrupt:
    print("\nServer is stopping...")
    sock.close()
