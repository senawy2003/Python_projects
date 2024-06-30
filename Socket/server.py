import socket
import threading

PORT = 5050
FORMAT = 'utf-8'
D = "DES"
HEADER = 64
SERVER = socket.gethostbyname(socket.gethostname())
ADDR =(SERVER,PORT)

server = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
server.bind(ADDR)

def send(msg, client):
    MSG = msg.encode(FORMAT)
    msg_len = len(MSG)
    send_len = str(msg_len).encode(FORMAT)
    send_len+=b''*(HEADER - len(send_len))
    client.send(send_len)
    client.send(msg)


def client(conn,addr,clients):
    print(f"{addr} is connected!")
    connected = True
    while connected:
        msg_len = conn.recv(HEADER).decode(FORMAT)
        if msg_len:
            msg_len = int(msg_len)
            msg = conn.recv(msg_len).decode(FORMAT)
            if msg_len == D:
                connected = False
            print(f"{addr}{msg}")
        for client in clients:
            if client != conn:
                send(msg,client)
    conn.close()

def start():
    server.listen()
    print(f"the server is listining to {SERVER}")
    clients = []
    while True:
        conn, addr = server.accept()
        clients.append(conn)
        thread = threading.Thread(target=client,args=(conn, addr,clients))
        thread.start()
print("the server is starting")
start()


