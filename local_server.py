

import http.server
import socketserver
import os

# Define the port for the server
PORT = 8000

# Define the directory to serve files from
# Use a raw string (r"...") to handle backslashes in the Windows path
DIRECTORY = r"C:\Development\labs\car-puzzle-app\moc-data"

class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    """A custom request handler that adds CORS headers and handles OPTIONS."""
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-control-allow-headers', 'content-type')
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        return super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200, "ok")
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

# Ensure the target directory exists
if not os.path.isdir(DIRECTORY):
    print(f"Error: Directory not found at '{DIRECTORY}'")
    exit()

# Change the current working directory to the specified directory
os.chdir(DIRECTORY)

# Create the server with the custom handler
class ThreadingTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    pass

with ThreadingTCPServer(('', PORT), CORSRequestHandler) as httpd:
    print(f"Serving files from: {DIRECTORY}")
    print(f"Server running at: http://localhost:{PORT}/")
    print("CORS headers are enabled for all origins, including OPTIONS requests.")
    print("\nPress Ctrl+C to stop the server.")
    
    # Start the server
    httpd.serve_forever()
