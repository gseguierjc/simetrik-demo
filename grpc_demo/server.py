import os
import sys
from concurrent import futures

# Para que Python encuentre el paquete generado bajo 'generated/'
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "generated"))

import grpc
import saludo.saludo_pb2      as saludo_pb2
import saludo.saludo_pb2_grpc as saludo_pb2_grpc

class Saludador(saludo_pb2_grpc.SaludadorServicer):
    def Saludar(self, request, context):
        mensaje = f"Hola, {request.nombre}!"
        return saludo_pb2.SaludoReply(mensaje=mensaje)

def serve():
    # Crea el servidor gRPC
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    saludo_pb2_grpc.add_SaludadorServicer_to_server(Saludador(), server)

    # Carga clave privada y certificado (auto-firmado)
    with open("/app/certs/server.key", "rb") as f:
        private_key = f.read()
    with open("/app/certs/server.crt", "rb") as f:
        certificate_chain = f.read()

    # Credenciales TLS
    server_credentials = grpc.ssl_server_credentials(
        [(private_key, certificate_chain)]
    )

    # Escucha en el puerto 50051 (local) y también en 0.0.0.0:443 (ALB público)
    server.add_secure_port("[::]:50051", server_credentials)
    server.add_secure_port("[::]:443", server_credentials)

    print("Servidor TLS escuchando en 0.0.0.0:50051 y 0.0.0.0:443 …")
    server.start()
    server.wait_for_termination()

if __name__ == "__main__":
    serve()
