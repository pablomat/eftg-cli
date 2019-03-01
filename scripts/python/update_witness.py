#!/usr/bin/env python3
import json, sys
from beem import Steem
from beem.witness import Witness
from beem.account import Account
from beemgraphenebase.account import PrivateKey, PublicKey 
from argparse import ArgumentParser
from beem.instance import set_shared_steem_instance

stmf = Steem(node=["https://api.blkcc.xyz"])

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
parser.add_argument('operation', help="Type of operation (update/disable)", type=str, nargs=1)
parser.add_argument('account', help="Name of the EFTG account", type=str, nargs=1)
parser.add_argument('privateactivekey', help="Private active key of the account", type=str, nargs=1)
parser.add_argument('--publicownerkey', help="Public owner key of the account", type=str)
parser.add_argument('--url', help="URL to display for this witness account", type=str)
parser.add_argument('--creationfee', help="Account creation fee to advertise as a witness", type=str)
parser.add_argument('--blocksize', help="Blocksize to advertise as a witness", type=int)
parser.add_argument('--interestrate', help="Interest rate to advertise as a witness", type=int)
args = parser.parse_args()
if (args.operation[0] == "update"):   
    if checkwit(args.account[0]):
        if not checkkey(args.account[0], args.privateactivekey[0], "active"): sys.exit("Private active key " + args.privateactivekey[0] + " doesn't prove authority for user " + args.account[0])
        wit = Witness(args.account[0], steem_instance=stmf)
        #Witness exists
        #take stuff from blockchain, if the user doesn't provide the args
        if not args.publicownerkey:
            my_publickey = str(wit.json()["signing_key"])
        else:
            try:
                PublicKey(args.publicownerkey, prefix="EUR")
            except:
                sys.exit("Wrong public key syntax " + args.publicownerkey)
            else:
                my_publickey = str(args.publicownerkey)
        
        if not args.url:
            my_url = str(wit.json()["url"])
        else:
            my_url = str(args.url)

        if not args.creationfee:
            my_fee = str(wit.json()["props"]["account_creation_fee"]) 
        else:
            my_fee = str(args.creationfee) 

        if not args.blocksize:
            my_blksize = int(wit.json()["props"]["maximum_block_size"]) 
        else:
            my_blksize = int(args.blocksize) 

        if not args.interestrate:
            my_rate = int(wit.json()["props"]["sbd_interest_rate"]) 
        else:
            my_rate = int(args.interestrate) 

        current = { "account_creation_fee": my_fee, "maximum_block_size": my_blksize, "sbd_interest_rate": my_rate }
    else:
        #witness doesn't exist
        #optional arguments are mandatory, the witness doesn't have stuff
        if not checkkey(args.account[0], args.privateactivekey[0], "active"): sys.exit("Private active key " + args.privateactivekey[0] + " doesn't prove authority for user " + args.account[0])
        if not args.publicownerkey: parser.error('The following argument is required for this operation: --publicownerkey')
        if not args.url: parser.error('The following argument is required for this operation: --url')
        if not args.creationfee: parser.error('The following argument is required for this operation: --creationfee')
        if not isinstance(args.blocksize, int): parser.error('The following argument is required for this operation: --blocksize')
        if not isinstance(args.interestrate, int): parser.error('The following argument is required for this operation: --interestrate')
        try:
            PublicKey(args.publicownerkey, prefix="EUR")
        except:
            sys.exit("Wrong public key syntax " + args.publicownerkey)
        else:
            my_publickey = str(args.publicownerkey)
        my_url = str(args.url)
        current = { "account_creation_fee": str(args.creationfee), "maximum_block_size": int(args.blocksize), "sbd_interest_rate": int(args.interestrate) }

elif (args.operation[0] == "disable"):
    if checkwit(args.account[0]):
        if not checkkey(args.account[0], args.privateactivekey[0], "active"): sys.exit("Private active key " + args.privateactivekey[0] + " doesn't prove authority for user " + args.account[0])
        wit = Witness(args.account[0], steem_instance=stmf)
        current = wit.json()["props"]
        my_url = str(wit.json()["url"])
    else:
         sys.exit("The account provided is not a valid witness in the EFTG Blockchain. Wrong witness " + args.account[0])

else:
    parser.error('Invalid input for argument "operation". ' + args.operation[0] + ' is invalid.' + ' Valid options are update or disable') 

stm = Steem(node=["https://api.blkcc.xyz"], keys=[args.privateactivekey[0]])
set_shared_steem_instance(stm)


if args.operation[0] == "disable":
    output = stm.witness_update("EUR1111111111111111111111111111111114T1Anm", my_url, current, args.account[0])
else:
    output = stm.witness_update(my_publickey, my_url, current, args.account[0])

print(json.dumps(output, indent=4))

# vim: set filetype=sh ts=4 sw=4 tw=0 wrap et:
