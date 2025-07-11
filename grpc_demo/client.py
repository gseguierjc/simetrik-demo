import os
import sys

# Para que Python encuentre el paquete generado bajo 'generated/'
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'generated'))

import grpc
from .generated.saludo import saludo_pb2, saludo_pb2_grpc

def run():
    creds   = grpc.ssl_channel_credentials()  # confía en tu self-signed
    options = (('grpc.ssl_target_name_override', 'grpc.local',),)
    channel = grpc.secure_channel('grpc.local:443', creds, options)
    stub    = saludo_pb2_grpc.SaludadorStub(channel)
    print(stub.Saludar(saludo_pb2.SaludoRequest(nombre="Jean")))


if __name__ == '__main__':
    run()
