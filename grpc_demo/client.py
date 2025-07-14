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
    target = os.environ.get("GRPC_TARGET", "demo-eks-grpc-demo-app-1202197144.us-east-1.elb.amazonaws.com:443")

    # 1) Carga tu CA autofirmada
    with open("certs/server.crt", "rb") as f:
        trusted_certs = f.read()
    creds = grpc.ssl_channel_credentials(root_certificates=trusted_certs)

    # 2) Forzar SNI Y :authority a "grpc.local"
    options = (
      ("grpc.ssl_target_name_override", "grpc.local"),   # SNI / validación TLS
      ("grpc.default_authority",       "grpc.local"),   # header HTTP/2 :authority
    )

    print("[DEBUG] Canal SEGURO a", target, "SNI=grpc.local AUTH=grpc.local")
    channel = grpc.secure_channel(target, creds, options)

    stub = saludo_pb2_grpc.SaludadorStub(channel)
    resp = stub.Saludar(saludo_pb2.SaludoRequest(nombre="Jean"))

if __name__ == "__main__":
    run()
