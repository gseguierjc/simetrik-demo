import os
import sys

# Para que Python encuentre el paquete generado bajo 'generated/'
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'generated'))

import grpc
from .generated.saludo import saludo_pb2, saludo_pb2_grpc

def run():
    # Carga el certificado raíz (server.crt) para confiar en el self-signed
    with open("server.crt", "rb") as f:
        trusted_certs = f.read()

    # Credenciales de canal TLS
    creds = grpc.ssl_channel_credentials(root_certificates=trusted_certs)

    # Opciones para pruebas:
    # - Local: conectas a localhost:50051 sin override de nombre
    # - Detrás de ALB: grpc.local:443 (configurado en /etc/hosts)
    target = os.environ.get("GRPC_TARGET", "localhost:50051")
    options = []
    if target.endswith(":443"):
        # el ALB espera SNI=grpc.local
        options = (('grpc.ssl_target_name_override', 'grpc.local',),)

    channel = grpc.secure_channel(target, creds, options)
    stub    = saludo_pb2_grpc.SaludadorStub(channel)

    respuesta = stub.Saludar(saludo_pb2.SaludoRequest(nombre="Jean"))
    print(respuesta.mensaje)

if __name__ == "__main__":
    run()
