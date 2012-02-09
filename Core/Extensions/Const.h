//
//  Const.h
//  GRTop
//
//  Created by artem samalov on 12/8/11.
//  Copyright (c) 2011 Team Force LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	ContentLanguageEnglish = 0,
	ContentLanguageAustralia,
	ContentLanguageEnglishUK,
	ContentLanguageMagyar,
	ContentLanguageDanish,
	ContentLanguageSpanish,
    ContentLanguageItalian,
	ContentLanguageChineseHongKong,
	ContentLanguageChineseTraditional,
	ContentLanguageChineseSimplified,
	ContentLanguageKorean,
	ContentLanguageGerman,
	ContentLanguageNorwegian,
    ContentLanguageNederlands,
	ContentLanguagePolish,
	ContentLanguagePortugueseBrasil,
	ContentLanguageRussian,
	ContentLanguageTurkish,
	ContentLanguageFinnish,
	ContentLanguageFrench,
	ContentLanguageCzech,
	ContentLanguageSwedish,
	ContentLanguageJapanese
} ContentLanguage;

#pragma mark General

#define APP_VERSION                     [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]
#define EMAIL_REGEXP_STRING             @"[a-z0-9!#$%&'*+/=?^_'{|}~-]+(?:\\.[a-z0-9!#$%&'*+/=?^_'{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?"

#define USER_LOGIN                      @""
#define USER_PASSWORD                   @""

#define PRIVATE_MODE_TYPE               @"private mode"
#define PUBLIC_MODE_TYPE                @"public mode"

#define CELL_ROW_HEIGHT                 80.0f
#define IMAGE_DETAIL_SIDE               90.0f

#pragma mark Tab Bar Controller Const

#define TB_TRENDS_ITEM_TITLE            @"Популярное"
#define TB_RECOMMENDED_ITEM_TITLE       @"Рекомендации"
#define TB_FUTURES_ITEM_TITLE           @"Подборка"
#define TB_BOOKMARKS_ITEM_TITLE         @"Закладки"

#define TB_TRENDS_ITEM_TAG              0
#define TB_RECOMMENDED_ITEM_TAG         1
#define TB_FUTURES_ITEM_TAG             2
#define TB_BOOKMARKS_ITEM_TAG           3

#pragma mark Path for resource

#define PATH_FOR_CACHES_FOLDER          @"/Library/Caches/"
#define PATH_FOR_IMAGE_CACHES_FOLDER    @"Images/"

#pragma mark - UILabel title

#define LABEL_LOADING_MORE_TITLE        @"Loading more..."
#define LABEL_LAST_UPDATE_TITLE         @"Last Updated:"
#define LABEL_PULL_DOWN_TITLE           @"Pull down to refresh..."
#define LABEL_RELEASE_REFRESH_TITLE     @"Release to refresh..."
#define LABEL_LOADING_STATUS_TITLE      @"Loading..."

#pragma mark - UIButton title

#define BUTTON_LOG_IN_TITLE             @"Войти"

#pragma mark - UIView title

#define ACCOUNT_VIEW_TITLE              @"Аккаунт"
#define TRENDS_VIEW_TITLE               @"Популярное"
#define RECOMMENDED_VIEW_TITLE          @"Рекомендации"
#define FUTURES_VIEW_TITLE              @"Подборка"
#define BOOKMARKS_VIEW_TITLE            @"Закладки"

#pragma mark - UITextField Placeholder

#define EMAIL_TEXT_FIELD_PLACEHOLDER    @"Gmail Address"
#define PASSWORD_TEXT_FIELD_PLACEHOLDER @"Password"

#pragma mark - UIAlertView strings

#define ALERT_ERROR_TITLE               @"Ошибка"

#define ALERT_ACCOUNT_INVALID           @"Неверный логин или пароль."
#define ALERT_ACCOUNT_Unavailable       @"Ваш аккаунт недоступен."
#define ALERT_ACCOUNT_FIELDS_EMPTY      @"Пожалуйста, введите email адрес и пароль."
#define ALERT_ACCOUNT_EMAIL_EMPTY       @"Пожалуйста, введите email адрес."
#define ALERT_ACCOUNT_PASSWORD_EMPTY    @"Пожалуйста, введите пароль."

#pragma mark - UITableView const

#define ACCOUNT_TABLE_SECTION_TITLE     @"Для получения доступа к личному топу, необходимо войти в Google аккаунт."

#pragma mark - Notification Center

#define UPDATE_LOGIN_BUTTON_STATE       @"UpdateLoginButtonState"
#define LOAD_ORIGIN_FEED                @"laoding origin feed"
#define TOUCH_ON_TOP_VIEW_NOTIFICATION  @"touch in top view notification"
#define OPEN_PHOTO_BROWSER_NOTIFICATION @"open photo browser"
#define OPEN_ORIGIN_FEED_NOTIFICATION   @"open origin feed"