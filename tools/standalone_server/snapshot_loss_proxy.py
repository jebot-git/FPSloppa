"""Loopback ENet fault proxy: deterministic packet loss and a one-second ACK blackout."""
import argparse,json,random,socket,select,time

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--listen',type=int,default=17791);p.add_argument('--server',type=int,default=17792);p.add_argument('--seconds',type=float,default=15);a=p.parse_args();rng=random.Random(3107)
 front=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);front.bind(('127.0.0.1',a.listen));back=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);back.bind(('127.0.0.1',0));peer=None;start=None;counts={'ack_blackout_packets':0,'lost_packets':0,'forwarded_packets':0}
 deadline=time.monotonic()+a.seconds
 while time.monotonic()<deadline:
  readable,_,_=select.select([front,back],[],[],.02)
  for sock in readable:
   data,address=sock.recvfrom(65535)
   if start is None:start=time.monotonic()
   elapsed=time.monotonic()-start
   if sock is front:
    peer=address
    if 1<elapsed<2.1 and b'CQS1\x19\x00\x00\x00' in data:counts['ack_blackout_packets']+=1;continue
   if rng.random()<.10:counts['lost_packets']+=1;continue
   if sock is front:back.sendto(data,('127.0.0.1',a.server))
   elif peer:front.sendto(data,peer)
   counts['forwarded_packets']+=1
 print(json.dumps(counts),flush=True)
 front.close();back.close()
if __name__=='__main__':main()
