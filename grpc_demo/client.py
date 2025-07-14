import os
import sys

# 1) Añade "generated/" al path
import os, sys

# 1) Añade 'generated/' en sys.path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "generated"))


import grpc
import saludo.saludo_pb2      as saludo_pb2
import saludo.saludo_pb2_grpc as saludo_pb2_grpc

def run():
    target = os.environ.get("GRPC_TARGET", "grpc.local:50051")
    # Siempre usaremos canal seguro
    # 1) Carga certificado raíz
    with open("/app/grpc_demo/certs/server.crt", "rb") as f:
        trusted_certs = f.read()
    creds = grpc.ssl_channel_credentials(root_certificates=trusted_certs)

    # 2) Forzamos SNI/hostname override a grpc.local
    options = (("grpc.ssl_target_name_override", "grpc.local"),)
    print("[DEBUG] Canal SEGURO a", target, "SNI=grpc.local")
    channel = grpc.secure_channel(target, creds, options)

    stub = saludo_pb2_grpc.SaludadorStub(channel)
    resp = stub.Saludar(saludo_pb2.SaludoRequest(nombre="Jean"))
    print(resp.mensaje)

if __name__ == "__main__":
    run()
