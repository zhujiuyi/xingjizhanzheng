-- A finite commander examination, backed by real settled activity receipts.
CREATE TABLE civilization_command_defs (
 faction_id TEXT PRIMARY KEY REFERENCES civilization_defs(faction_id),
 display_name TEXT NOT NULL,registration_rank INTEGER NOT NULL,command_rank INTEGER NOT NULL,
 required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
 reward_credit INTEGER NOT NULL CHECK(reward_credit>=0),reward_reputation INTEGER NOT NULL CHECK(reward_reputation>0),
 FOREIGN KEY(faction_id,registration_rank) REFERENCES civilization_rank_defs(faction_id,rank_level),
 FOREIGN KEY(faction_id,command_rank) REFERENCES civilization_rank_defs(faction_id,rank_level),
 CHECK(command_rank>=registration_rank)
) STRICT;
CREATE TABLE civilization_honor_task_defs (
 task_id TEXT PRIMARY KEY,faction_id TEXT NOT NULL REFERENCES civilization_command_defs(faction_id),
 task_kind TEXT NOT NULL CHECK(task_kind IN ('scout','logistics','rescue','combat')),
 display_name TEXT NOT NULL,required_units INTEGER NOT NULL CHECK(required_units>0),
 UNIQUE(faction_id,task_kind)
) STRICT;
CREATE TABLE civilization_honor_source_defs (
 task_id TEXT NOT NULL REFERENCES civilization_honor_task_defs(task_id),source_index INTEGER NOT NULL CHECK(source_index>=0),
 event_id TEXT REFERENCES exploration_event_defs(event_id),contract_id TEXT REFERENCES consignment_defs(contract_id),operation_id TEXT REFERENCES operation_defs(operation_id),
 PRIMARY KEY(task_id,source_index),CHECK((event_id IS NOT NULL)+(contract_id IS NOT NULL)+(operation_id IS NOT NULL)=1)
) STRICT;
