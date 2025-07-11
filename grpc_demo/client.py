import os
import sys

# Para que Python encuentre el paquete generado bajo 'generated/'
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'generated'))

import grpc
from .generated.saludo import saludo_pb2, saludo_pb2_grpc

def run():
    # Carga el certificado del servidor
    certs_dir = os.path.join(os.path.dirname(__file__), 'certs')
    with open(os.path.join(certs_dir, 'service-server.crt'), 'rb') as f:
        trusted_certs = f.read()

    # Credenciales TLS para el cliente
    credentials = grpc.ssl_channel_credentials(root_certificates=trusted_certs)
    channel = grpc.secure_channel('localhost:50051', credentials)

    stub = saludo_pb2_grpc.SaludadorStub(channel)
    respuesta = stub.Saludar(saludo_pb2.SaludoRequest(nombre="Jean"))
    print("Respuesta:", respuesta.mensaje)

if __name__ == '__main__':
    run()
