"""Bounded private/control transport. Bind to loopback; use tunnels between hosts."""
import asyncio
import json

LIMIT = 1024 * 1024
TIMEOUT = 3.0


def encode(value):
    data = json.dumps(value, separators=(',', ':'), allow_nan=False).encode()+b'\n'
    if len(data) > LIMIT:
        raise ValueError('Message exceeds 1 MiB')
    return data


async def read(reader, timeout=TIMEOUT):
    line = await asyncio.wait_for(reader.readline(), timeout)
    if not line:
        raise ConnectionError('Connection closed')
    if len(line)>LIMIT:
        raise ValueError('Message exceeds bound')
    value = json.loads(line, parse_constant=lambda _: (_ for _ in ()).throw(ValueError('Nonfinite number')))
    if not isinstance(value,dict):
        raise ValueError('Object required')
    return value


async def send(writer, value):
    if writer.transport.get_write_buffer_size()>LIMIT:
        raise ConnectionError('Slow peer exceeded queue budget')
    writer.write(encode(value))
    await asyncio.wait_for(writer.drain(),TIMEOUT)


async def rpc(address, message):
    reader, writer = await asyncio.wait_for(asyncio.open_connection(*address,limit=LIMIT),TIMEOUT)
    try:
        await send(writer,message)
        result=await read(reader)
        if 'error' in result:
            raise ValueError(result['error'])
        return result['result']
    finally:
        writer.close()
        await writer.wait_closed()
