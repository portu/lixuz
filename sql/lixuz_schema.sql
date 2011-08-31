-- MySQL dump 10.11
--
-- Host: localhost    Database: lixuz
-- ------------------------------------------------------
-- Server version	5.0.51a-24+lenny5

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `lz_action`
--

DROP TABLE IF EXISTS `lz_action`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_action` (
  `action_id` int(11) NOT NULL auto_increment,
  `action_path` varchar(60) NOT NULL,
  PRIMARY KEY  (`action_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_article`
--

DROP TABLE IF EXISTS `lz_article`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_article` (
  `article_id` int(11) NOT NULL auto_increment,
  `status_id` int(11) default NULL,
  `title` varchar(255) default NULL,
  `lead` text,
  `body` text,
  `author` varchar(100) default NULL,
  `creator` int(11) default NULL,
  `assignee` int(11) default NULL,
  `template_id` int(11) default NULL,
  `modified_time` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `created_time` timestamp NOT NULL default '0000-00-00 00:00:00',
  `publish_time` timestamp NULL default NULL,
  `expiry_time` timestamp NULL default NULL,
  `trashed` tinyint(1) default '0',
  `live_comments` tinyint(1) default '0',
  `revision` int(6) NOT NULL default '1',
  PRIMARY KEY  (`article_id`,`revision`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_article_elements`
--

DROP TABLE IF EXISTS `lz_article_elements`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_article_elements` (
  `article_id` int(11) NOT NULL,
  `keyvalue_id` int(11) NOT NULL,
  `revision` int(6) NOT NULL default '1',
  PRIMARY KEY  (`article_id`,`keyvalue_id`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_article_file`
--

DROP TABLE IF EXISTS `lz_article_file`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_article_file` (
  `article_id` int(11) NOT NULL,
  `file_id` int(11) NOT NULL,
  `spot_no` int(3) default NULL,
  `caption` text,
  `revision` int(6) NOT NULL default '1',
  PRIMARY KEY  (`article_id`,`file_id`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_article_folder`
--

DROP TABLE IF EXISTS `lz_article_folder`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_article_folder` (
  `article_id` int(11) NOT NULL,
  `folder_id` int(11) NOT NULL,
  `primary_folder` tinyint(1) NOT NULL,
  `revision` int(6) NOT NULL default '1',
  PRIMARY KEY  (`article_id`,`folder_id`,`primary_folder`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_article_lock`
--

DROP TABLE IF EXISTS `lz_article_lock`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_article_lock` (
  `article_id` int(11) NOT NULL,
  `locked_by_user` int(11) NOT NULL,
  `locked_at` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`article_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_article_relations`
--

DROP TABLE IF EXISTS `lz_article_relations`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_article_relations` (
  `article_id` int(11) NOT NULL,
  `related_article_id` int(11) NOT NULL,
  `relation_type` enum('previous','related') NOT NULL,
  `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `revision` int(6) NOT NULL default '1',
  PRIMARY KEY  (`article_id`,`related_article_id`,`relation_type`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_article_tag`
--

DROP TABLE IF EXISTS `lz_article_tag`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_article_tag` (
  `tag_id` int(11) NOT NULL,
  `article_id` int(11) NOT NULL,
  `added_by` int(11) NOT NULL,
  `revision` int(6) NOT NULL default '0',
  PRIMARY KEY  (`tag_id`,`article_id`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_article_watch`
--

DROP TABLE IF EXISTS `lz_article_watch`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_article_watch` (
  `article_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  PRIMARY KEY  (`article_id`,`user_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_backup`
--

DROP TABLE IF EXISTS `lz_backup`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_backup` (
  `backup_id` int(14) NOT NULL auto_increment,
  `saved_date` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `user_id` int(11) NOT NULL,
  `backup_source` enum('article') NOT NULL,
  `backup_source_id` int(11) default NULL,
  `backup_string` text,
  PRIMARY KEY  (`backup_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_category`
--

DROP TABLE IF EXISTS `lz_category`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_category` (
  `category_id` int(11) NOT NULL auto_increment,
  `category_name` varchar(255) default NULL,
  `parent` int(11) default NULL,
  `root_parent` int(11) default NULL,
  `category_order` int(11) default NULL,
  `template_id` int(11) default NULL,
  `display_type_id` int(11) default NULL,
  `folder_id` int(11) default NULL,
  `external_link` text,
  `category_status` enum('Active','Inactive') default 'Active',
  PRIMARY KEY  (`category_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_category_folder`
--

DROP TABLE IF EXISTS `lz_category_folder`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_category_folder` (
  `category_id` int(11) NOT NULL,
  `folder_id` int(11) NOT NULL,
  PRIMARY KEY  (`category_id`,`folder_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_field`
--

DROP TABLE IF EXISTS `lz_field`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_field` (
  `field_id` int(11) NOT NULL auto_increment,
  `field_name` varchar(100) default NULL,
  `field_type` enum('singleline','multiline','user-pulldown','predefined-pulldown','multi-select','checkbox','range','meta-int','meta-date','meta-other','datetime','date') default NULL,
  `field_height` smallint(6) default NULL,
  `field_richtext` tinyint(1) default '0',
  `field_range` varchar(20) default NULL,
  `inline` varchar(19) default NULL,
  `exclusive_module` enum('articles','workflow','users','roles','folders','templates','files') default NULL,
  `obligatory` tinyint(1) default '0',
  PRIMARY KEY  (`field_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_field_module`
--

DROP TABLE IF EXISTS `lz_field_module`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_field_module` (
  `field_module_id` int(11) NOT NULL auto_increment,
  `field_id` int(11) NOT NULL,
  `module` enum('articles','workflow','users','roles','folders','templates','files') NOT NULL,
  `object_id` int(11) default NULL,
  `position` smallint(6) default NULL,
  `enabled` tinyint(1) default '1',
  PRIMARY KEY  (`field_module_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_field_options`
--

DROP TABLE IF EXISTS `lz_field_options`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_field_options` (
  `field_id` int(11) NOT NULL,
  `option_id` smallint(6) NOT NULL auto_increment,
  `option_name` varchar(100) default NULL,
  `range_from` int(10) default NULL,
  `range_to` int(10) default NULL,
  PRIMARY KEY  (`field_id`,`option_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_field_value`
--

DROP TABLE IF EXISTS `lz_field_value`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_field_value` (
  `field_id` int(11) NOT NULL,
  `module_id` int(11) NOT NULL,
  `value` text,
  `module_name` enum('articles','workflow','users','roles','folders','templates','files') NOT NULL,
  `revision` int(6) NOT NULL default '1',
  PRIMARY KEY  (`field_id`,`module_id`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_file`
--

DROP TABLE IF EXISTS `lz_file`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_file` (
  `file_id` int(11) NOT NULL auto_increment,
  `file_name` varchar(100) default NULL,
  `path` varchar(255) default NULL,
  `folder_id` int(11) default NULL,
  `owner` int(11) default NULL,
  `title` varchar(255) default NULL,
  `caption` text,
  `width` smallint(5) default NULL,
  `height` smallint(5) default NULL,
  `size` int(11) default NULL,
  `format` char(5) default NULL,
  `last_edited` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `upload_time` timestamp NOT NULL default '0000-00-00 00:00:00',
  `clone` int(11) default NULL,
  `status` enum('Active','Inactive') default 'Active',
  `trashed` tinyint(1) default NULL,
  `identifier` varchar(10) default NULL,
  `class_id` int(11) NOT NULL default '0',
  PRIMARY KEY  (`file_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_file_class`
--

DROP TABLE IF EXISTS `lz_file_class`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_file_class` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(254) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_file_tag`
--

DROP TABLE IF EXISTS `lz_file_tag`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_file_tag` (
  `tag_id` int(11) NOT NULL,
  `file_id` int(11) NOT NULL,
  `added_by` int(11) NOT NULL,
  PRIMARY KEY  (`tag_id`,`file_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_folder`
--

DROP TABLE IF EXISTS `lz_folder`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_folder` (
  `folder_id` int(11) NOT NULL auto_increment,
  `folder_name` varchar(100) default NULL,
  `parent` int(11) default NULL,
  `folder_order` int(11) default NULL,
  PRIMARY KEY  (`folder_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_key_value`
--

DROP TABLE IF EXISTS `lz_key_value`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_key_value` (
  `keyvalue_id` int(11) NOT NULL auto_increment,
  `thekey` char(156) NOT NULL,
  `value` text,
  `type` enum('dictionary','url') NOT NULL,
  PRIMARY KEY  (`keyvalue_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_live_captcha`
--

DROP TABLE IF EXISTS `lz_live_captcha`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_live_captcha` (
  `captcha_id` int(20) NOT NULL auto_increment,
  `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `captcha` char(10) NOT NULL,
  PRIMARY KEY  (`captcha_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_live_comment`
--

DROP TABLE IF EXISTS `lz_live_comment`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_live_comment` (
  `comment_id` int(11) NOT NULL auto_increment,
  `article_id` int(11) NOT NULL,
  `ip` char(15) NOT NULL,
  `author_name` char(128) default NULL,
  `subject` char(255) default NULL,
  `body` text,
  `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP,
  PRIMARY KEY  (`comment_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_lixuz_meta`
--

DROP TABLE IF EXISTS `lz_lixuz_meta`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_lixuz_meta` (
  `meta_id` int(11) NOT NULL auto_increment,
  `entry` varchar(20) default NULL,
  `VALUE` varchar(254) default NULL,
  PRIMARY KEY  (`meta_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_newsletter_group`
--

DROP TABLE IF EXISTS `lz_newsletter_group`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_newsletter_group` (
  `group_id` int(11) NOT NULL auto_increment,
  `group_name` varchar(254) NOT NULL,
  `internal` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`group_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_newsletter_saved`
--

DROP TABLE IF EXISTS `lz_newsletter_saved`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_newsletter_saved` (
  `saved_id` int(11) NOT NULL auto_increment,
  `sent_by_user` int(11) NOT NULL,
  `from_address` varchar(254) default NULL,
  `subject` varchar(254) default NULL,
  `body` text,
  `format` enum('text','html') default NULL,
  `sent_at` timestamp NOT NULL default CURRENT_TIMESTAMP,
  PRIMARY KEY  (`saved_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_newsletter_subscription`
--

DROP TABLE IF EXISTS `lz_newsletter_subscription`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_newsletter_subscription` (
  `subscription_id` int(11) NOT NULL auto_increment,
  `email` varchar(254) NOT NULL,
  `name` varchar(254) NOT NULL,
  `format` enum('text','html') NOT NULL default 'text',
  `send_every` enum('month','week','day') NOT NULL default 'week',
  `last_sent` datetime default NULL,
  `validation_hash` varchar(100) default NULL,
  `validated` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`subscription_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_newsletter_subscription_category`
--

DROP TABLE IF EXISTS `lz_newsletter_subscription_category`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_newsletter_subscription_category` (
  `category_id` int(11) NOT NULL,
  `subscription_id` int(11) NOT NULL,
  PRIMARY KEY  (`category_id`,`subscription_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_newsletter_subscription_group`
--

DROP TABLE IF EXISTS `lz_newsletter_subscription_group`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_newsletter_subscription_group` (
  `group_id` int(11) NOT NULL,
  `subscription_id` int(11) NOT NULL,
  PRIMARY KEY  (`group_id`,`subscription_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_perms`
--

DROP TABLE IF EXISTS `lz_perms`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_perms` (
  `perm_id` int(11) NOT NULL auto_increment,
  `user_id` int(11) default NULL,
  `role_id` int(11) default NULL,
  `object_id` int(11) NOT NULL,
  `object_type` enum('folder','file') NOT NULL,
  `permission` tinyint(1) NOT NULL,
  `added_by_user_id` int(11) NOT NULL,
  PRIMARY KEY  (`perm_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_revision`
--

DROP TABLE IF EXISTS `lz_revision`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_revision` (
  `revision_id` int(11) NOT NULL auto_increment,
  `type` enum('article') NOT NULL,
  `type_id` int(11) NOT NULL,
  `type_revision` int(11) NOT NULL,
  `is_latest` tinyint(1) NOT NULL default '1',
  `created_at` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `committer` int(11) default NULL,
  `is_latest_in_status` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`revision_id`),
  KEY `revision_meta_standard` (`type_id`,`type_revision`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_role`
--

DROP TABLE IF EXISTS `lz_role`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_role` (
  `role_id` int(11) NOT NULL auto_increment,
  `role_name` varchar(100) default NULL,
  `role_status` enum('Active','Inactive') default 'Active',
  PRIMARY KEY  (`role_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_role_action`
--

DROP TABLE IF EXISTS `lz_role_action`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_role_action` (
  `action_id` int(11) NOT NULL,
  `role_id` int(11) NOT NULL,
  `allowed` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`action_id`,`role_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_rss_article`
--

DROP TABLE IF EXISTS `lz_rss_article`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_rss_article` (
  `rss_id` int(11) NOT NULL auto_increment,
  `guid` varchar(129) NOT NULL,
  `pubdate` datetime default NULL,
  `title` varchar(255) default NULL,
  `lead` text,
  `link` varchar(255) default NULL,
  `source` varchar(255) default NULL,
  `deleted` tinyint(1) default '0',
  `status` enum('Active','Inactive') default 'Inactive',
  PRIMARY KEY  (`rss_id`),
  UNIQUE KEY `guid` (`guid`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_status`
--

DROP TABLE IF EXISTS `lz_status`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_status` (
  `status_id` int(11) NOT NULL auto_increment,
  `status_name` varchar(56) default NULL,
  `system_status` enum('0','1') default '0',
  PRIMARY KEY  (`status_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_tag`
--

DROP TABLE IF EXISTS `lz_tag`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_tag` (
  `tag_id` int(11) NOT NULL auto_increment,
  `name` varchar(254) default NULL,
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL default CURRENT_TIMESTAMP,
  PRIMARY KEY  (`tag_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_template`
--

DROP TABLE IF EXISTS `lz_template`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_template` (
  `template_id` int(11) NOT NULL auto_increment,
  `name` varchar(254) default NULL,
  `file` varchar(254) NOT NULL,
  `type` enum('list','search','article','include','message','rssimport','email_text','email_html') default NULL,
  `apiversion` int(4) NOT NULL,
  `uniqueid` varchar(254) NOT NULL,
  `is_default` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`template_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_template_dependencies`
--

DROP TABLE IF EXISTS `lz_template_dependencies`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_template_dependencies` (
  `dependency_id` int(11) NOT NULL auto_increment,
  `template_id` int(11) NOT NULL,
  `dependency` varchar(200) default NULL,
  PRIMARY KEY  (`dependency_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_template_includes`
--

DROP TABLE IF EXISTS `lz_template_includes`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_template_includes` (
  `include_id` int(11) NOT NULL auto_increment,
  `template_id` int(11) NOT NULL,
  `dependency_id` int(11) default NULL,
  `dependency_uniqueid` varchar(254) default NULL,
  PRIMARY KEY  (`include_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_user`
--

DROP TABLE IF EXISTS `lz_user`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_user` (
  `user_id` int(11) NOT NULL auto_increment,
  `role_id` int(11) default NULL,
  `user_name` varchar(50) default NULL,
  `firstname` varchar(50) default NULL,
  `lastname` varchar(50) default NULL,
  `email` varchar(100) default NULL,
  `password` varchar(32) default NULL,
  `user_status` enum('Active','Inactive') default 'Active',
  `last_login` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `created` timestamp NOT NULL default '0000-00-00 00:00:00',
  `lang` varchar(6) default NULL,
  PRIMARY KEY  (`user_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_user_config`
--

DROP TABLE IF EXISTS `lz_user_config`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_user_config` (
  `user_id` int(11) NOT NULL default '0',
  `name` varchar(20) NOT NULL default '',
  `value` text,
  PRIMARY KEY  (`user_id`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_widget_config`
--

DROP TABLE IF EXISTS `lz_widget_config`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_widget_config` (
  `widget_config_id` int(11) NOT NULL auto_increment,
  `widget_name` char(20) NOT NULL,
  `config_user` int(11) default NULL,
  `config_name` char(20) NOT NULL,
  `config_value` char(255) default NULL,
  `global` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`widget_config_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_workflow`
--

DROP TABLE IF EXISTS `lz_workflow`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_workflow` (
  `article_id` int(11) NOT NULL,
  `priority` tinyint(4) default NULL,
  `deadline` datetime default NULL,
  `hours_estimated` int(11) default NULL,
  `hours_used` int(11) default NULL,
  `start_date` datetime default NULL,
  `assigned_by` int(11) default NULL,
  `assigned_to_user` int(11) default NULL,
  `assigned_to_role` int(11) default NULL,
  `revision` int(6) NOT NULL default '1',
  PRIMARY KEY  (`article_id`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `lz_workflow_comments`
--

DROP TABLE IF EXISTS `lz_workflow_comments`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `lz_workflow_comments` (
  `article_id` int(11) NOT NULL,
  `user_id` int(11) default NULL,
  `comment_body` text,
  `comment_subject` varchar(255) default NULL,
  `written_time` datetime default NULL,
  `comment_id` int(11) NOT NULL auto_increment,
  `on_revision` int(5) NOT NULL default '1',
  PRIMARY KEY  (`comment_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2011-04-05  8:14:03
