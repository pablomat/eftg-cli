#!/usr/bin/env python3
import json, sys
from beem import Steem
from beem.witness import Witness
from beem.account import Account
from beemgraphenebase.account import PrivateKey, PublicKey 
from argparse import ArgumentParser
from beem.instance import set_shared_steem_instance

stmf = Steem(node=["https://api.eftg.eu"])

def checkwit(username):
    try:
        wit = Witness(username, steem_instance=stmf)
    except Exception as exception:
        assert type(exception).__name__ == 'WitnessDoesNotExistsException'
        assert exception.__class__.__name__ == 'WitnessDoesNotExistsException'
        return False
    else:
        return True

def checkkey(username, password, role):
    listOfValidRoles = ['owner' , 'active', 'posting', 'memo']
    if role not in listOfValidRoles:
        print(role + " NOT found in List : " , listOfValidRoles)
        sys.exit("Wrong role " + role)

    try:
        account = Account(username, steem_instance=stmf)
    except:
        sys.exit("Wrong username " + username)

    try:
        publickey = str(PrivateKey(password, prefix="EUR").pubkey)
    except:
        sys.exit("Wrong password syntax " + password)

    blk_auths_public = {}
    if role == "memo": 
        blk_auths_public[role] = str(account.json()["memo_key"])
    else:
        blk_auths_public[role] = str(account.json()[role]["key_auths"][0][0])

    if publickey == blk_auths_public[role]:
        return True
    else:
        return False

parser = ArgumentParser()
parser.add_argument('witness', help="Name of the EFTG Witness", type=str, nargs=1)
parser.add_argument('privateactivekey', help="Private active key of the Witness", type=str, nargs=1)
parser.add_argument('baseprice', help="New feed price in EUR to publish for a 1.000 EFTG quote. E.G.: \"4.700\"", type=float, nargs=1)
args = parser.parse_args()

if checkwit(args.witness[0]):
    if not checkkey(args.witness[0], args.privateactivekey[0], "active"): sys.exit("Private active key " + args.privateactivekey[0] + " doesn't prove authority for Witness " + args.witness[0])
    #Witness exists
    stm = Steem(node=["https://api.eftg.eu"], keys=[args.privateactivekey[0]])
    set_shared_steem_instance(stm)

    my_feed = "{:.3f} EUR".format(args.baseprice[0])
    wit = Witness(args.witness[0])

    output = wit.feed_publish(my_feed)
    print(json.dumps(output, indent=4))

else:
     sys.exit("The account provided is not a valid witness in the EFTG Blockchain. Wrong witness " + args.account[0])

# vim: set filetype=sh ts=4 sw=4 tw=0 wrap et:
