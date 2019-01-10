#!/usr/bin/env python3
import json, sys
from beem import Steem
from beem.account import Account
from beemgraphenebase.account import PrivateKey, PublicKey 
from argparse import ArgumentParser
from beem.instance import set_shared_steem_instance

stmf = Steem(node=["https://api.blkcc.xyz"])

def checkacc(username):
    try:
        acc = Account(username, steem_instance=stmf)
    except Exception as exception:
        assert type(exception).__name__ == 'AccountDoesNotExistsException'
        assert exception.__class__.__name__ == 'AccountDoesNotExistsException'
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
parser.add_argument('account', help="Name of the EFTG account", type=str, nargs=1)
parser.add_argument('privateactivekey', help="Private active key of the account", type=str, nargs=1)
parser.add_argument('--name', help="Display name", type=str)
parser.add_argument('--about', help="About", type=str)
parser.add_argument('--location', help="Location", type=str)
parser.add_argument('--profile_image', help="Profile picture URL", type=str)
parser.add_argument('--cover_image', help="Cover image URL", type=str)
parser.add_argument('--website', help="Website", type=str)
args = parser.parse_args()

if checkacc(args.account[0]):
    if not checkkey(args.account[0], args.privateactivekey[0], "active"): sys.exit("Private active key " + args.privateactivekey[0] + " doesn't prove authority for user " + args.account[0])

    acc = Account(args.account[0], steem_instance=stmf)

    profile = acc.profile

    #Account exists
    #take stuff from blockchain, if the user doesn't provide the args
    if args.name: profile["name"] = str(args.name)

    if args.about: profile["about"] = str(args.about)

    if args.location: profile["location"] = str(args.location)

    if args.profile_image: profile["profile_image"] = str(args.profile_image)

    if args.cover_image: profile["cover_image"] = str(args.cover_image)

    if args.website: profile["website"] = str(args.website)

    stm = Steem(node=["https://api.blkcc.xyz"], keys=[args.privateactivekey[0]])
    set_shared_steem_instance(stm)

    output = acc.update_account_profile(profile)

    print(json.dumps(output, indent=4))

else:
    sys.exit("The account provided is not a valid account in the EFTG Blockchain. Wrong account " + args.account[0])

# vim: set filetype=sh ts=4 sw=4 tw=0 wrap et:
