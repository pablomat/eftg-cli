#!/usr/bin/env python3
from functions import checkacc, checkwit, checkkey, checkwif, getcred
from beem import Steem
from beem.account import Account
from getpass import unix_getpass
from beemgraphenebase.account import PasswordKey
from beem.transactionbuilder import TransactionBuilder
from beembase import operations
from argparse import ArgumentParser
from beem.instance import set_shared_steem_instance
import json, sys

stm = Steem(node=["https://api.blkcc.xyz"])
set_shared_steem_instance(stm)
prefix = stm.prefix

parser = ArgumentParser()
parser.add_argument('account', type=str, nargs=1)
parser.add_argument('--store-credentials', help="If used, a file with all new credentials will be saved", action='store_true')
args = parser.parse_args()

if checkacc(args.account[0]): 
    acc = Account(args.account[0])
else:
    sys.exit("The account provided is not a valid account in the EFTG Blockchain. Wrong account " + args.account[0])

cur_password = unix_getpass(prompt='Current password for @%s: ' %
                            (acc['name']))

if not checkwif(acc['name'], cur_password): sys.exit("Password provided is not correct.")

new_password = unix_getpass(prompt='New password for @%s: ' %
                            (acc['name']))
repeat_pwd = unix_getpass(prompt='Repeat new password for @%s: ' %
                          (acc['name']))

assert(new_password == repeat_pwd)

signing_key = PasswordKey(acc['name'], cur_password, role="owner", prefix=prefix)
wif = str(signing_key.get_private_key())

#Since we're going to build a transaction is simpler to do everything here instead of using a function
key_auths_public = {}
key_auths_private = {}
for role in ['owner', 'active', 'posting', 'memo']:
    pk = PasswordKey(acc['name'], new_password, role=role, prefix="EUR")
    key_auths_public[role] = str(pk.get_public_key())
    key_auths_private[role] = str(pk.get_private_key())

op = operations.Account_update(
    **{
        "account": acc["name"],
        'owner': {
             'account_auths': [],
             'key_auths': [[key_auths_public['owner'], 1]],
             "address_auths": [],
             'weight_threshold': 1},
        'active': {
             'account_auths': [],
             'key_auths': [[key_auths_public['active'], 1]],
             "address_auths": [],
             'weight_threshold': 1},
        'posting': {
             'account_auths': acc['posting']['account_auths'],
             'key_auths': [[key_auths_public['posting'], 1]],
             "address_auths": [],
             'weight_threshold': 1},
        'memo_key': key_auths_public['memo'],
        "json_metadata": acc['json_metadata'],
        "prefix": prefix,
    })

ops = [op]
tb = TransactionBuilder()
tb.appendOps(ops)
tb.appendWif(wif)
tb.sign()
output = tb.broadcast()

data = {"name":acc['name'],"wif":new_password,"owner":[{"type":"public","value":key_auths_public["owner"]},{"type":"private","value":key_auths_private["owner"]}],"active":[{"type":"public","value":key_auths_public["active"]},{"type":"private","value":key_auths_private["active"]}],"posting":[{"type":"public","value":key_auths_public["posting"]},{"type":"private","value":key_auths_private["posting"]}],"memo":[{"type":"public","value":key_auths_public["memo"]},{"type":"private","value":key_auths_private["memo"]}]}

print(json.dumps(output, indent=4))

if args.store_credentials:
    #creds = getcred(acc['name'], new_password)
    with open(acc['name']+".json", 'w') as f: json.dump(data, f)
    print(json.dumps(data, indent=4))
else:
    print(json.dumps(data, indent=4))

# vim: set filetype=sh ts=4 sw=4 tw=0 wrap et:
