from beem.account import Account
from beem.witness import Witness
from beemgraphenebase.account import PasswordKey, PrivateKey, PublicKey
import json, sys

def checkacc(username):
    try:
        acc = Account(username)
    except Exception as exception:
        assert type(exception).__name__ == 'AccountDoesNotExistsException'
        assert exception.__class__.__name__ == 'AccountDoesNotExistsException'
        return False
    else:
        return True

def checkwit(username):
    try:
        wit = Witness(username)
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
        account = Account(username)
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

def checkwif(username, wif):
    key_auths_public = {}
    blk_auths_public = {}

    try:
        account = Account(username)
    except:
        return False

    for role in ['owner', 'active', 'posting', 'memo']:
        pk = PasswordKey(username, wif, role=role, prefix="EUR")
        key_auths_public[role] = str(pk.get_public_key())
        if role == "memo":
            blk_auths_public[role] = str(account.json()["memo_key"])
        else:
            blk_auths_public[role] = str(account.json()[role]["key_auths"][0][0])

        if key_auths_public[role] != blk_auths_public[role]:
            return False
    return True

def getcred(username, wif):
    key_auths_public = {}
    key_auths_private = {}
    for role in ['owner', 'active', 'posting', 'memo']:
        pk = PasswordKey(username, wif, role=role, prefix="EUR")
        key_auths_public[role] = str(pk.get_public_key())
        key_auths_private[role] = str(pk.get_private_key())

    data = {"name":username,"wif":wif,"owner":[{"type":"public","value":key_auths_public["owner"]},{"type":"private","value":key_auths_private["owner"]}],"active":[{"type":"public","value":key_auths_public["active"]},{"type":"private","value":key_auths_private["active"]}],"posting":[{"type":"public","value":key_auths_public["posting"]},{"type":"private","value":key_auths_private["posting"]}],"memo":[{"type":"public","value":key_auths_public["memo"]},{"type":"private","value":key_auths_private["memo"]}]}
    print(json.dumps(data, indent=4))

# vim: set filetype=sh ts=4 sw=4 tw=0 wrap et:
