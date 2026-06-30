CREATE INDEX IF NOT EXISTS `ix_frame_messages_frame_uuid` ON `frame_messages` (`frame_id`, (CASE WHEN json_valid(msg_json) THEN json_extract(msg_json,'$._uuid') END));
