-- v0 -> v13 (compatible with v9+): Latest revision
CREATE TABLE "user" (
	bridge_id       TEXT NOT NULL,
	mxid            TEXT NOT NULL,

	management_room TEXT,
	access_token    TEXT,

	PRIMARY KEY (bridge_id, mxid)
);

CREATE TABLE user_login (
	bridge_id   TEXT  NOT NULL,
	user_mxid   TEXT  NOT NULL,
	id          TEXT  NOT NULL,
	remote_name TEXT  NOT NULL,
	space_room  TEXT,
	metadata    jsonb NOT NULL,

	PRIMARY KEY (bridge_id, id),
	CONSTRAINT user_login_user_fkey FOREIGN KEY (bridge_id, user_mxid)
		REFERENCES "user" (bridge_id, mxid)
		ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE portal (
	bridge_id       TEXT    NOT NULL,
	id              TEXT    NOT NULL,
	receiver        TEXT    NOT NULL,
	mxid            TEXT,

	parent_id       TEXT,
	-- This is not accessed by the bridge, it's only used for the portal parent foreign key.
	-- Parent groups are probably never DMs, so they don't need a receiver.
	parent_receiver TEXT    NOT NULL DEFAULT '',

	relay_bridge_id TEXT,
	relay_login_id  TEXT,

	other_user_id   TEXT,

	name            TEXT    NOT NULL,
	topic           TEXT    NOT NULL,
	avatar_id       TEXT    NOT NULL,
	avatar_hash     TEXT    NOT NULL,
	avatar_mxc      TEXT    NOT NULL,
	name_set        BOOLEAN NOT NULL,
	avatar_set      BOOLEAN NOT NULL,
	topic_set       BOOLEAN NOT NULL,
	in_space        BOOLEAN NOT NULL,
	room_type       TEXT    NOT NULL,
	disappear_type  TEXT,
	disappear_timer BIGINT,
	metadata        jsonb   NOT NULL,

	PRIMARY KEY (bridge_id, id, receiver),
	CONSTRAINT portal_parent_fkey FOREIGN KEY (bridge_id, parent_id, parent_receiver)
		-- Deletes aren't allowed to cascade here:
		-- children should be re-parented or cleaned up manually
		REFERENCES portal (bridge_id, id, receiver) ON UPDATE CASCADE,
	CONSTRAINT portal_relay_fkey FOREIGN KEY (relay_bridge_id, relay_login_id)
		REFERENCES user_login (bridge_id, id)
		ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE ghost (
	bridge_id        TEXT    NOT NULL,
	id               TEXT    NOT NULL,

	name             TEXT    NOT NULL,
	avatar_id        TEXT    NOT NULL,
	avatar_hash      TEXT    NOT NULL,
	avatar_mxc       TEXT    NOT NULL,
	name_set         BOOLEAN NOT NULL,
	avatar_set       BOOLEAN NOT NULL,
	contact_info_set BOOLEAN NOT NULL,
	is_bot           BOOLEAN NOT NULL,
	identifiers      jsonb   NOT NULL,
	metadata         jsonb   NOT NULL,

	PRIMARY KEY (bridge_id, id)
);

CREATE TABLE message (
	-- Messages have an extra rowid to allow a single relates_to column with ON DELETE SET NULL
	-- If the foreign key used (bridge_id, relates_to), then deleting the target column
	-- would try to set bridge_id to null as well.

	-- only: sqlite (line commented)
--	rowid      INTEGER PRIMARY KEY,
	-- only: postgres
	rowid            BIGINT PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,

	bridge_id        TEXT    NOT NULL,
	id               TEXT    NOT NULL,
	part_id          TEXT    NOT NULL,
	mxid             TEXT    NOT NULL,

	room_id          TEXT    NOT NULL,
	room_receiver    TEXT    NOT NULL,
	sender_id        TEXT    NOT NULL,
	sender_mxid      TEXT    NOT NULL,
	timestamp        BIGINT  NOT NULL,
	edit_count       INTEGER NOT NULL,
	thread_root_id   TEXT,
	reply_to_id      TEXT,
	reply_to_part_id TEXT,
	metadata         jsonb   NOT NULL,

	CONSTRAINT message_room_fkey FOREIGN KEY (bridge_id, room_id, room_receiver)
		REFERENCES portal (bridge_id, id, receiver)
		ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT message_sender_fkey FOREIGN KEY (bridge_id, sender_id)
		REFERENCES ghost (bridge_id, id)
		ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT message_real_pkey UNIQUE (bridge_id, room_receiver, id, part_id)
);
CREATE INDEX message_room_idx ON message (bridge_id, room_id, room_receiver);

CREATE TABLE disappearing_message (
	bridge_id    TEXT   NOT NULL,
	mx_room      TEXT   NOT NULL,
	mxid         TEXT   NOT NULL,
	type         TEXT   NOT NULL,
	timer        BIGINT NOT NULL,
	disappear_at BIGINT,

	PRIMARY KEY (bridge_id, mxid)
);

CREATE TABLE reaction (
	bridge_id       TEXT   NOT NULL,
	message_id      TEXT   NOT NULL,
	message_part_id TEXT   NOT NULL,
	sender_id       TEXT   NOT NULL,
	emoji_id        TEXT   NOT NULL,
	room_id         TEXT   NOT NULL,
	room_receiver   TEXT   NOT NULL,
	mxid            TEXT   NOT NULL,

	timestamp       BIGINT NOT NULL,
	emoji           TEXT   NOT NULL,
	metadata        jsonb  NOT NULL,

	PRIMARY KEY (bridge_id, room_receiver, message_id, message_part_id, sender_id, emoji_id),
	CONSTRAINT reaction_room_fkey FOREIGN KEY (bridge_id, room_id, room_receiver)
		REFERENCES portal (bridge_id, id, receiver)
		ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT reaction_message_fkey FOREIGN KEY (bridge_id, room_receiver, message_id, message_part_id)
		REFERENCES message (bridge_id, room_receiver, id, part_id)
		ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT reaction_sender_fkey FOREIGN KEY (bridge_id, sender_id)
		REFERENCES ghost (bridge_id, id)
		ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX reaction_room_idx ON reaction (bridge_id, room_id, room_receiver);

CREATE TABLE user_portal (
	bridge_id       TEXT    NOT NULL,
	user_mxid       TEXT    NOT NULL,
	login_id        TEXT    NOT NULL,
	portal_id       TEXT    NOT NULL,
	portal_receiver TEXT    NOT NULL,
	in_space        BOOLEAN NOT NULL,
	preferred       BOOLEAN NOT NULL,
	last_read       BIGINT,

	PRIMARY KEY (bridge_id, user_mxid, login_id, portal_id, portal_receiver),
	CONSTRAINT user_portal_user_login_fkey FOREIGN KEY (bridge_id, login_id)
		REFERENCES user_login (bridge_id, id)
		ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT user_portal_portal_fkey FOREIGN KEY (bridge_id, portal_id, portal_receiver)
		REFERENCES portal (bridge_id, id, receiver)
		ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX user_portal_login_idx ON user_portal (bridge_id, login_id);
CREATE INDEX user_portal_portal_idx ON user_portal (bridge_id, portal_id, portal_receiver);

CREATE TABLE backfill_queue (
	bridge_id            TEXT    NOT NULL,
	portal_id            TEXT    NOT NULL,
	portal_receiver      TEXT    NOT NULL,
	user_login_id        TEXT    NOT NULL,

	batch_count          INTEGER NOT NULL,
	is_done              BOOLEAN NOT NULL,
	cursor               TEXT,
	oldest_message_id    TEXT,
	dispatched_at        BIGINT,
	completed_at         BIGINT,
	next_dispatch_min_ts BIGINT  NOT NULL,

	PRIMARY KEY (bridge_id, portal_id, portal_receiver),
	CONSTRAINT backfill_queue_portal_fkey FOREIGN KEY (bridge_id, portal_id, portal_receiver)
		REFERENCES portal (bridge_id, id, receiver)
		ON DELETE CASCADE ON UPDATE CASCADE
);
