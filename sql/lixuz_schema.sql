-- MySQL dump 10.13  Distrib 5.1.66, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: lixuz
-- ------------------------------------------------------
-- Server version	5.1.66-0+squeeze1

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
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_action` (
  `action_id` int(11) NOT NULL AUTO_INCREMENT,
  `action_path` varchar(60) NOT NULL,
  PRIMARY KEY (`action_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_article`
--

DROP TABLE IF EXISTS `lz_article`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_article` (
  `article_id` int(11) NOT NULL AUTO_INCREMENT,
  `status_id` int(11) DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `lead` text,
  `body` text,
  `author` varchar(100) DEFAULT NULL,
  `creator` int(11) DEFAULT NULL,
  `assignee` int(11) DEFAULT NULL,
  `template_id` int(11) DEFAULT NULL,
  `modified_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `publish_time` timestamp NULL DEFAULT NULL,
  `expiry_time` timestamp NULL DEFAULT NULL,
  `trashed` tinyint(1) DEFAULT '0',
  `live_comments` tinyint(1) DEFAULT '0',
  `revision` int(6) NOT NULL DEFAULT '1',
  PRIMARY KEY (`article_id`,`revision`),
  KEY `article_status` (`status_id`),
  KEY `article_trashed` (`trashed`),
  KEY `article_expiry_time` (`expiry_time`),
  KEY `article_publish_time` (`publish_time`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_article_elements`
--

DROP TABLE IF EXISTS `lz_article_elements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_article_elements` (
  `article_id` int(11) NOT NULL,
  `keyvalue_id` int(11) NOT NULL,
  `revision` int(6) NOT NULL DEFAULT '1',
  PRIMARY KEY (`article_id`,`keyvalue_id`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_article_file`
--

DROP TABLE IF EXISTS `lz_article_file`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_article_file` (
  `article_id` int(11) NOT NULL,
  `file_id` int(11) NOT NULL,
  `spot_no` int(3) DEFAULT NULL,
  `caption` text,
  `revision` int(6) NOT NULL DEFAULT '1',
  PRIMARY KEY (`article_id`,`file_id`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_article_folder`
--

DROP TABLE IF EXISTS `lz_article_folder`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_article_folder` (
  `article_id` int(11) NOT NULL,
  `folder_id` int(11) NOT NULL,
  `primary_folder` tinyint(1) NOT NULL,
  `revision` int(6) NOT NULL DEFAULT '1',
  PRIMARY KEY (`article_id`,`folder_id`,`primary_folder`,`revision`),
  KEY `article_folder_artid` (`article_id`),
  KEY `article_folder_revision` (`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_article_lock`
--

DROP TABLE IF EXISTS `lz_article_lock`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_article_lock` (
  `article_id` int(11) NOT NULL,
  `locked_by_user` int(11) NOT NULL,
  `locked_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`article_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_article_relations`
--

DROP TABLE IF EXISTS `lz_article_relations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_article_relations` (
  `article_id` int(11) NOT NULL,
  `related_article_id` int(11) NOT NULL,
  `relation_type` enum('previous','related') NOT NULL,
  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `revision` int(6) NOT NULL DEFAULT '1',
  PRIMARY KEY (`article_id`,`related_article_id`,`relation_type`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_article_tag`
--

DROP TABLE IF EXISTS `lz_article_tag`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_article_tag` (
  `tag_id` int(11) NOT NULL,
  `article_id` int(11) NOT NULL,
  `added_by` int(11) NOT NULL,
  `revision` int(6) NOT NULL DEFAULT '0',
  PRIMARY KEY (`tag_id`,`article_id`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_article_watch`
--

DROP TABLE IF EXISTS `lz_article_watch`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_article_watch` (
  `article_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  PRIMARY KEY (`article_id`,`user_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_backup`
--

DROP TABLE IF EXISTS `lz_backup`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_backup` (
  `backup_id` int(14) NOT NULL AUTO_INCREMENT,
  `saved_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `user_id` int(11) NOT NULL,
  `backup_source` enum('article') NOT NULL,
  `backup_source_id` int(11) DEFAULT NULL,
  `backup_string` text,
  PRIMARY KEY (`backup_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_category`
--

DROP TABLE IF EXISTS `lz_category`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_category` (
  `category_id` int(11) NOT NULL AUTO_INCREMENT,
  `category_name` varchar(255) DEFAULT NULL,
  `parent` int(11) DEFAULT NULL,
  `root_parent` int(11) DEFAULT NULL,
  `category_order` int(11) DEFAULT NULL,
  `template_id` int(11) DEFAULT NULL,
  `display_type_id` int(11) DEFAULT NULL,
  `folder_id` int(11) DEFAULT NULL,
  `external_link` text,
  `category_status` enum('Active','Inactive') DEFAULT 'Active',
  PRIMARY KEY (`category_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_category_folder`
--

DROP TABLE IF EXISTS `lz_category_folder`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_category_folder` (
  `category_id` int(11) NOT NULL,
  `folder_id` int(11) NOT NULL,
  PRIMARY KEY (`category_id`,`folder_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_category_layout`
--

DROP TABLE IF EXISTS `lz_category_layout`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_category_layout` (
  `category_id` int(11) NOT NULL,
  `article_id` int(11) NOT NULL,
  `template_id` int(11) NOT NULL,
  `spot` smallint(6) NOT NULL,
  `ordered_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`category_id`,`article_id`,`template_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_field`
--

DROP TABLE IF EXISTS `lz_field`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_field` (
  `field_id` int(11) NOT NULL AUTO_INCREMENT,
  `field_name` varchar(100) DEFAULT NULL,
  `field_type` enum('singleline','multiline','user-pulldown','predefined-pulldown','multi-select','checkbox','range','meta-int','meta-date','meta-other','datetime','date') DEFAULT NULL,
  `field_height` smallint(6) DEFAULT NULL,
  `field_richtext` tinyint(1) DEFAULT '0',
  `field_range` varchar(20) DEFAULT NULL,
  `inline` varchar(19) DEFAULT NULL,
  `exclusive_module` enum('articles','workflow','users','roles','folders','templates','files') DEFAULT NULL,
  `obligatory` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`field_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_field_module`
--

DROP TABLE IF EXISTS `lz_field_module`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_field_module` (
  `field_module_id` int(11) NOT NULL AUTO_INCREMENT,
  `field_id` int(11) NOT NULL,
  `module` enum('articles','workflow','users','roles','folders','templates','files') NOT NULL,
  `object_id` int(11) DEFAULT NULL,
  `position` smallint(6) DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`field_module_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_field_options`
--

DROP TABLE IF EXISTS `lz_field_options`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_field_options` (
  `field_id` int(11) NOT NULL,
  `option_id` smallint(6) NOT NULL AUTO_INCREMENT,
  `option_name` varchar(100) DEFAULT NULL,
  `range_from` int(10) DEFAULT NULL,
  `range_to` int(10) DEFAULT NULL,
  PRIMARY KEY (`field_id`,`option_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_field_value`
--

DROP TABLE IF EXISTS `lz_field_value`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_field_value` (
  `field_id` int(11) NOT NULL,
  `module_id` int(11) NOT NULL,
  `value` text,
  `dt_value` datetime DEFAULT NULL,
  `module_name` enum('articles','workflow','users','roles','folders','templates','files') NOT NULL,
  `revision` int(6) NOT NULL DEFAULT '1',
  PRIMARY KEY (`field_id`,`module_id`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_file`
--

DROP TABLE IF EXISTS `lz_file`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_file` (
  `file_id` int(11) NOT NULL AUTO_INCREMENT,
  `file_name` varchar(100) DEFAULT NULL,
  `path` varchar(255) DEFAULT NULL,
  `owner` int(11) DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `caption` text,
  `width` smallint(5) DEFAULT NULL,
  `height` smallint(5) DEFAULT NULL,
  `size` int(11) DEFAULT NULL,
  `format` char(5) DEFAULT NULL,
  `last_edited` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `upload_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `clone` int(11) DEFAULT NULL,
  `status` enum('Active','Inactive') DEFAULT 'Active',
  `trashed` tinyint(1) DEFAULT NULL,
  `identifier` varchar(10) DEFAULT NULL,
  `class_id` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`file_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_file_class`
--

DROP TABLE IF EXISTS `lz_file_class`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_file_class` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(254) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_file_folder`
--

DROP TABLE IF EXISTS `lz_file_folder`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_file_folder` (
  `file_id` int(11) NOT NULL,
  `folder_id` int(11) NOT NULL,
  `primary_folder` tinyint(1) NOT NULL,
  PRIMARY KEY (`file_id`,`folder_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_file_tag`
--

DROP TABLE IF EXISTS `lz_file_tag`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_file_tag` (
  `tag_id` int(11) NOT NULL,
  `file_id` int(11) NOT NULL,
  `added_by` int(11) NOT NULL,
  PRIMARY KEY (`tag_id`,`file_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_folder`
--

DROP TABLE IF EXISTS `lz_folder`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_folder` (
  `folder_id` int(11) NOT NULL AUTO_INCREMENT,
  `folder_name` varchar(100) DEFAULT NULL,
  `parent` int(11) DEFAULT NULL,
  `folder_order` int(11) DEFAULT NULL,
  PRIMARY KEY (`folder_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_key_value`
--

DROP TABLE IF EXISTS `lz_key_value`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_key_value` (
  `keyvalue_id` int(11) NOT NULL AUTO_INCREMENT,
  `thekey` char(156) NOT NULL,
  `value` text,
  `type` enum('dictionary','url') NOT NULL,
  PRIMARY KEY (`keyvalue_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_live_captcha`
--

DROP TABLE IF EXISTS `lz_live_captcha`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_live_captcha` (
  `captcha_id` int(20) NOT NULL AUTO_INCREMENT,
  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `captcha` char(10) NOT NULL,
  PRIMARY KEY (`captcha_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_live_comment`
--

DROP TABLE IF EXISTS `lz_live_comment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_live_comment` (
  `comment_id` int(11) NOT NULL AUTO_INCREMENT,
  `article_id` int(11) NOT NULL,
  `ip` char(15) NOT NULL,
  `author_name` char(128) DEFAULT NULL,
  `subject` char(255) DEFAULT NULL,
  `body` text,
  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`comment_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_lixuz_meta`
--

DROP TABLE IF EXISTS `lz_lixuz_meta`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_lixuz_meta` (
  `meta_id` int(11) NOT NULL AUTO_INCREMENT,
  `entry` varchar(20) DEFAULT NULL,
  `VALUE` varchar(254) DEFAULT NULL,
  PRIMARY KEY (`meta_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_newsletter_group`
--

DROP TABLE IF EXISTS `lz_newsletter_group`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_newsletter_group` (
  `group_id` int(11) NOT NULL AUTO_INCREMENT,
  `group_name` varchar(254) NOT NULL,
  `internal` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`group_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_newsletter_saved`
--

DROP TABLE IF EXISTS `lz_newsletter_saved`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_newsletter_saved` (
  `saved_id` int(11) NOT NULL AUTO_INCREMENT,
  `sent_by_user` int(11) NOT NULL,
  `from_address` varchar(254) DEFAULT NULL,
  `subject` varchar(254) DEFAULT NULL,
  `body` text,
  `format` enum('text','html') DEFAULT NULL,
  `sent_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`saved_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_newsletter_subscription`
--

DROP TABLE IF EXISTS `lz_newsletter_subscription`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_newsletter_subscription` (
  `subscription_id` int(11) NOT NULL AUTO_INCREMENT,
  `email` varchar(254) NOT NULL,
  `name` varchar(254) NOT NULL,
  `format` enum('text','html') NOT NULL DEFAULT 'text',
  `send_every` enum('month','week','day') NOT NULL DEFAULT 'week',
  `last_sent` datetime DEFAULT NULL,
  `validation_hash` varchar(100) DEFAULT NULL,
  `validated` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`subscription_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_newsletter_subscription_category`
--

DROP TABLE IF EXISTS `lz_newsletter_subscription_category`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_newsletter_subscription_category` (
  `category_id` int(11) NOT NULL,
  `subscription_id` int(11) NOT NULL,
  PRIMARY KEY (`category_id`,`subscription_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_newsletter_subscription_group`
--

DROP TABLE IF EXISTS `lz_newsletter_subscription_group`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_newsletter_subscription_group` (
  `group_id` int(11) NOT NULL,
  `subscription_id` int(11) NOT NULL,
  PRIMARY KEY (`group_id`,`subscription_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_perms`
--

DROP TABLE IF EXISTS `lz_perms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_perms` (
  `perm_id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `role_id` int(11) DEFAULT NULL,
  `object_id` int(11) NOT NULL,
  `object_type` enum('folder','file') NOT NULL,
  `permission` tinyint(1) NOT NULL,
  `added_by_user_id` int(11) NOT NULL,
  PRIMARY KEY (`perm_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_revision`
--

DROP TABLE IF EXISTS `lz_revision`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_revision` (
  `revision_id` int(11) NOT NULL AUTO_INCREMENT,
  `type` enum('article') NOT NULL,
  `type_id` int(11) NOT NULL,
  `type_revision` int(11) NOT NULL,
  `is_latest` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `committer` int(11) DEFAULT NULL,
  `is_latest_in_status` tinyint(1) NOT NULL DEFAULT '0',
  `is_latest_exclusive_status` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`revision_id`),
  KEY `revision_meta_standard` (`type_id`,`type_revision`),
  KEY `revision_meta_type_id` (`type_id`),
  KEY `revision_meta_type_revision` (`type_revision`),
  KEY `revision_meta_is_latest` (`is_latest`),
  KEY `revision_meta_is_latest_in_status` (`is_latest_in_status`),
  KEY `revision_meta_is_latest_exclusive_status` (`is_latest_exclusive_status`),
  KEY `revision_meta_type` (`type`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_role`
--

DROP TABLE IF EXISTS `lz_role`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_role` (
  `role_id` int(11) NOT NULL AUTO_INCREMENT,
  `role_name` varchar(100) DEFAULT NULL,
  `role_status` enum('Active','Inactive') DEFAULT 'Active',
  PRIMARY KEY (`role_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_role_action`
--

DROP TABLE IF EXISTS `lz_role_action`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_role_action` (
  `action_id` int(11) NOT NULL,
  `role_id` int(11) NOT NULL,
  `allowed` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`action_id`,`role_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_rss_article`
--

DROP TABLE IF EXISTS `lz_rss_article`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_rss_article` (
  `rss_id` int(11) NOT NULL AUTO_INCREMENT,
  `guid` varchar(129) NOT NULL,
  `pubdate` datetime DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `lead` text,
  `link` varchar(255) DEFAULT NULL,
  `source` varchar(255) DEFAULT NULL,
  `deleted` tinyint(1) DEFAULT '0',
  `status` enum('Active','Inactive') DEFAULT 'Inactive',
  PRIMARY KEY (`rss_id`),
  UNIQUE KEY `guid` (`guid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_status`
--

DROP TABLE IF EXISTS `lz_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_status` (
  `status_id` int(11) NOT NULL AUTO_INCREMENT,
  `status_name` varchar(56) DEFAULT NULL,
  `system_status` enum('0','1') DEFAULT '0',
  `exclusive` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`status_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_tag`
--

DROP TABLE IF EXISTS `lz_tag`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_tag` (
  `tag_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(254) DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`tag_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_template`
--

DROP TABLE IF EXISTS `lz_template`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_template` (
  `template_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(254) DEFAULT NULL,
  `file` varchar(254) NOT NULL,
  `type` enum('list','search','article','include','message','rssimport','email_text','email_html','media') DEFAULT NULL,
  `apiversion` int(4) NOT NULL,
  `uniqueid` varchar(254) NOT NULL,
  `is_default` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`template_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_template_dependencies`
--

DROP TABLE IF EXISTS `lz_template_dependencies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_template_dependencies` (
  `dependency_id` int(11) NOT NULL AUTO_INCREMENT,
  `template_id` int(11) NOT NULL,
  `dependency` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`dependency_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_template_includes`
--

DROP TABLE IF EXISTS `lz_template_includes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_template_includes` (
  `include_id` int(11) NOT NULL AUTO_INCREMENT,
  `template_id` int(11) NOT NULL,
  `dependency_id` int(11) DEFAULT NULL,
  `dependency_uniqueid` varchar(254) DEFAULT NULL,
  PRIMARY KEY (`include_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_user`
--

DROP TABLE IF EXISTS `lz_user`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_user` (
  `user_id` int(11) NOT NULL AUTO_INCREMENT,
  `role_id` int(11) DEFAULT NULL,
  `user_name` varchar(50) DEFAULT NULL,
  `firstname` varchar(50) DEFAULT NULL,
  `lastname` varchar(50) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `password` varchar(32) DEFAULT NULL,
  `user_status` enum('Active','Inactive') DEFAULT 'Active',
  `last_login` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `lang` varchar(6) DEFAULT NULL,
  `reset_code` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`user_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_user_config`
--

DROP TABLE IF EXISTS `lz_user_config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_user_config` (
  `user_id` int(11) NOT NULL DEFAULT '0',
  `name` varchar(20) NOT NULL DEFAULT '',
  `value` text,
  PRIMARY KEY (`user_id`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_widget_config`
--

DROP TABLE IF EXISTS `lz_widget_config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_widget_config` (
  `widget_config_id` int(11) NOT NULL AUTO_INCREMENT,
  `widget_name` char(20) NOT NULL,
  `config_user` int(11) DEFAULT NULL,
  `config_name` char(20) NOT NULL,
  `config_value` char(255) DEFAULT NULL,
  `global` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`widget_config_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_workflow`
--

DROP TABLE IF EXISTS `lz_workflow`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_workflow` (
  `article_id` int(11) NOT NULL,
  `priority` tinyint(4) DEFAULT NULL,
  `deadline` datetime DEFAULT NULL,
  `hours_estimated` int(11) DEFAULT NULL,
  `hours_used` int(11) DEFAULT NULL,
  `start_date` datetime DEFAULT NULL,
  `assigned_by` int(11) DEFAULT NULL,
  `assigned_to_user` int(11) DEFAULT NULL,
  `assigned_to_role` int(11) DEFAULT NULL,
  `revision` int(6) NOT NULL DEFAULT '1',
  PRIMARY KEY (`article_id`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lz_workflow_comments`
--

DROP TABLE IF EXISTS `lz_workflow_comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lz_workflow_comments` (
  `article_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `comment_body` text,
  `comment_subject` varchar(255) DEFAULT NULL,
  `written_time` datetime DEFAULT NULL,
  `comment_id` int(11) NOT NULL AUTO_INCREMENT,
  `on_revision` int(5) NOT NULL DEFAULT '1',
  PRIMARY KEY (`comment_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2013-05-15 12:12:46
