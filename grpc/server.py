import os
import sys

# Para que Python encuentre el paquete generado bajo 'generated/'
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'generated'))

import grpc
from concurrent import futures
from saludo import saludo_pb2, saludo_pb2_grpc

class Saludador(saludo_pb2_grpc.SaludadorServicer):
    def Saludar(self, request, context):
        mensaje = f"Hola, {request.nombre}!"
        return saludo_pb2.SaludoReply(mensaje=mensaje)

def serve():
    # Carga la clave privada y el certificado
    certs_dir = os.path.join(os.path.dirname(__file__), 'certs')
    with open(os.path.join(certs_dir, 'server.key'), 'rb') as f:
        private_key = f.read()
    with open(os.path.join(certs_dir, 'server.crt'), 'rb') as f:
        certificate_chain = f.read()

    # Credenciales TLS para el servidor
    server_credentials = grpc.ssl_server_credentials(
        ((private_key, certificate_chain),)
    )

    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    saludo_pb2_grpc.add_SaludadorServicer_to_server(Saludador(), server)
    server.add_secure_port('[::]:50051', server_credentials)
    print("Servidor TLS escuchando en el puerto 50051...")
    server.start()
    server.wait_for_termination()

if __name__ == '__main__':
    serve()
