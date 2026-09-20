"""Durable local transactions or shared linearizable etcd CAS transactions.

Only metadata is stored. Never send actor snapshots through this store.
"""
import base64
import copy
import json
import sqlite3
import threading
import time
import urllib.request
from . import model


def mutate(state, message, gateway):
    if message['op']=='status':
        return model.view(state,gateway,time.time()),False
    result=model.apply(state,message,gateway,time.time())
    state['revision']+=1
    assert max(model.counts(state).values(),default=0)<=model.CAPACITY
    return result,True


class SQLiteStore:
    def __init__(self,path,initial):
        self.lock=threading.Lock()
        self.db=sqlite3.connect(path,check_same_thread=False)
        self.db.execute('PRAGMA journal_mode=WAL')
        self.db.execute('PRAGMA synchronous=FULL')
        self.db.execute('CREATE TABLE IF NOT EXISTS state (id INTEGER PRIMARY KEY CHECK(id=1), body TEXT NOT NULL)')
        self.db.execute('INSERT OR IGNORE INTO state VALUES (1,?)',(json.dumps(initial),))
        self.db.commit()

    def execute(self,message,gateway):
        with self.lock:
            self.db.execute('BEGIN IMMEDIATE')
            try:
                state=json.loads(self.db.execute('SELECT body FROM state WHERE id=1').fetchone()[0])
                result,changed=mutate(state,message,gateway)
                if changed:
                    self.db.execute('UPDATE state SET body=? WHERE id=1',(json.dumps(state,separators=(',',':')),))
                self.db.commit()
                return result
            except BaseException:
                self.db.rollback()
                raise


class EtcdStore:
    """Stateless coordinator frontends share one etcd key with revision CAS.

    Prototype intentionally serializes control writes. This is availability,
    not throughput sharding. One key is bounded below etcd's request limit.
    """
    def __init__(self,endpoints,key,initial):
        self.endpoints=endpoints
        self.key=base64.b64encode(key.encode()).decode()
        self.initial=copy.deepcopy(initial)

    def post(self,path,body):
        last=None
        for endpoint in self.endpoints:
            try:
                req=urllib.request.Request(endpoint+path,json.dumps(body).encode(),{'Content-Type':'application/json'})
                with urllib.request.urlopen(req,timeout=.7) as response:
                    result=json.load(response)
                if 'error' in result:
                    raise ConnectionError(result['error'])
                return result
            except (OSError,ValueError) as error:
                last=error
        raise ConnectionError('Coordinator quorum unavailable') from last

    def execute(self,message,gateway):
        for _ in range(64):
            records=self.post('/v3/kv/range',{'key':self.key}).get('kvs',[])
            if records:
                row=records[0];revision=row['mod_revision']
                state=json.loads(base64.b64decode(row['value']))
            else:
                revision='0';state=copy.deepcopy(self.initial)
            result,changed=mutate(state,message,gateway)
            if not changed and records:
                return result
            data=json.dumps(state,separators=(',',':')).encode()
            if len(data)>700000:
                raise model.Rejected('Coordinator metadata budget exceeded')
            answer=self.post('/v3/kv/txn',{'compare':[{'key':self.key,'target':'MOD','result':'EQUAL','mod_revision':revision}], 'success':[{'request_put':{'key':self.key,'value':base64.b64encode(data).decode()}}]})
            if answer.get('succeeded'):
                return result
        raise ConnectionError('Coordinator contention budget exceeded; retry')
