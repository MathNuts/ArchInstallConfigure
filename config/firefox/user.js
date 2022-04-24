//
// --- Firefox custom settings

// Hardware acceleration
user_pref("loaded-custom-settings", true);
user_pref("media.ffmpeg.vaapi.enabled", true);
/*user_pref("media.rdd-ffmpeg.enabled", true);
user_pref("media.ffvpx.enabled", false);
user_pref("media.navigator.mediadatadecoder_vpx_enabled", true);
user_pref("media.rdd-vpx.enabled", false);*/

// PiP disable
user_pref("media.videocontrols.picture-in-picture.video-toggle.enabled", false);

// Sync restrict to only Bookmarks, Setting and Add-ons
user_pref("services.sync.declinedEngines", "passwords,tabs,forms,creditcards,history");
user_pref("services.sync.engine.history", false);
user_pref("services.sync.engine.passwords", false);
user_pref("services.sync.engine.prefs.modified", false);
user_pref("services.sync.engine.tabs", false);

// Do not save logins
user_pref("signon.rememberSignons",	false);

// Devtools
user_pref("devtools.toolbox.host", "right");

// Disable DRM - Temporary!
user_pref("media.gmp-widevinecdm.visible", false);