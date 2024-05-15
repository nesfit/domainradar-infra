#!/usr/bin/env python3

from aiokafka import AIOKafkaConsumer
from ssl import create_default_context, Purpose
import asyncio

async def run():
        cafile="/files/secrets/ca/ca-cert"
        certfile="/files/secrets/secrets_client1/client1-cert.pem"
        keyfile="/files/secrets/secrets_client1/client1-priv-key.pem"
        password="secret_client1_password"

        context = create_default_context(Purpose.SERVER_AUTH, cafile=cafile)
        context.load_cert_chain(certfile, keyfile, password)
        context.check_hostname = True

        consumer = AIOKafkaConsumer(bootstrap_servers=['kafka1:9093', 'kafka2:9094'],
                                    ssl_context=context, security_protocol='SSL')
        try:
                await consumer.start()
                topics = await consumer.topics()
                print("Topics:\n", topics)
        except Exception as e:
                print("Error:", e)
        finally:
                await consumer.stop()
    

asyncio.run(run())
