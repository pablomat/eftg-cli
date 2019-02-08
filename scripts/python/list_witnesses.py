#!/usr/bin/env python3
from beem.witness import ListWitnesses
from beem.instance import set_shared_steem_instance

from beem import Steem
stm = Steem(node=["https://api.eftg.eu"])

set_shared_steem_instance(stm)

print(ListWitnesses())
