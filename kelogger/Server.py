import socket
import threading



PORT = 5050
FORMAT = 'utf-8'

def handle_client(conn, addr):
    print(f"New connection from {addr}")
    while True:
        try:
            data = conn.recv(1024).decode(FORMAT)
            if not data:
                break
            print(f"Recev.: {data}")
        except ConnectionResetError:
            break
    conn.close()

def start_server():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(('0.0.0.0', PORT))
    server.listen()
    print(f"Server listening on port {PORT}")

    while True:
        conn, addr = server.accept()
        client_thread = threading.Thread(target=handle_client, args=(conn, addr))
        client_thread.start()

if __name__ == '__main__':
    start_server()
