package com.hhy0111.territoryconquestidle.ads;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.RequestConfiguration;
import com.google.android.gms.ads.appopen.AppOpenAd;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import com.google.android.ump.ConsentInformation;
import com.google.android.ump.ConsentRequestParameters;
import com.google.android.ump.FormError;
import com.google.android.ump.UserMessagingPlatform;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class TerritoryConquestAdsPlugin extends GodotPlugin {
	private static final long APP_OPEN_MAX_AGE_MS = 4L * 60L * 60L * 1000L;
	private static final String TAG = "TerritoryConquestAds";
	private static final String PLUGIN_NAME = "TerritoryConquestAds";

	private final Handler mainHandler = new Handler(Looper.getMainLooper());
	private final Map<String, SlotConfig> appOpenSlots = new HashMap<>();
	private final Map<String, SlotConfig> rewardedSlots = new HashMap<>();
	private final Map<String, SlotConfig> interstitialSlots = new HashMap<>();
	private final Map<String, AppOpenAd> appOpenAds = new HashMap<>();
	private final Map<String, RewardedAd> rewardedAds = new HashMap<>();
	private final Map<String, InterstitialAd> interstitialAds = new HashMap<>();
	private final Map<String, Boolean> appOpenLoading = new HashMap<>();
	private final Map<String, Boolean> rewardedLoading = new HashMap<>();
	private final Map<String, Boolean> interstitialLoading = new HashMap<>();
	private final Map<String, Long> appOpenLoadTimes = new HashMap<>();
	private final Map<String, Boolean> rewardedEarned = new HashMap<>();
	private final List<String> testDeviceIds = new ArrayList<>();
	private final List<Runnable> pendingInitializationActions = new ArrayList<>();

	private JSONObject runtimeConfig = new JSONObject();
	private ConsentInformation consentInformation;
	private boolean runtimeConfigured = false;
	private boolean consentEnabled = false;
	private boolean adsInitialized = false;
	private boolean adsInitializing = false;
	private String pendingAppOpenShowSlot = "";
	private String pendingRewardedShowSlot = "";
	private String pendingInterstitialShowSlot = "";


	public TerritoryConquestAdsPlugin(Godot godot) {
		super(godot);
	}


	@NonNull
	@Override
	public String getPluginName() {
		return PLUGIN_NAME;
	}


	@NonNull
	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new HashSet<>();
		signals.add(new SignalInfo("consent_result", String.class, String.class));
		signals.add(new SignalInfo("consent_status_changed", String.class));
		signals.add(new SignalInfo("app_open_closed", String.class));
		signals.add(new SignalInfo("app_open_failed", String.class, String.class));
		signals.add(new SignalInfo("rewarded_completed", String.class));
		signals.add(new SignalInfo("rewarded_failed", String.class, String.class));
		signals.add(new SignalInfo("interstitial_closed", String.class));
		signals.add(new SignalInfo("interstitial_failed", String.class, String.class));
		return signals;
	}


	@UsedByGodot
	public void configure_runtime(String runtimeJson) {
		if (TextUtils.isEmpty(runtimeJson)) {
			Log.w(TAG, "Ignored empty runtime config payload.");
			return;
		}

		try {
			runtimeConfig = new JSONObject(runtimeJson);
			parseRuntimeConfig(runtimeConfig);
			runtimeConfigured = true;
			applyRequestConfiguration();

			if (!consentEnabled) {
				emitConsentStatus("not_required", "Consent disabled in runtime config.");
				initializeMobileAdsIfNeeded(null);
			} else if (canRequestAds()) {
				initializeMobileAdsIfNeeded(null);
			}
		} catch (JSONException exception) {
			Log.e(TAG, "Failed to parse runtime config.", exception);
			emitConsentStatus("error", "Runtime config parse failed: " + exception.getMessage());
		}
	}


	@UsedByGodot
	public boolean request_consent() {
		if (!runtimeConfigured) {
			Log.w(TAG, "request_consent called before configure_runtime.");
			return false;
		}

		if (!consentEnabled) {
			emitConsentStatus("not_required", "Consent disabled in runtime config.");
			initializeMobileAdsIfNeeded(null);
			return true;
		}

		runOnActivityUiThread(this::startConsentFlow);
		return true;
	}


	@UsedByGodot
	public boolean show_app_open(String slotKey, String unitId) {
		SlotConfig slot = resolveSlot(slotKey, unitId, "app_open");
		if (slot == null || !slot.enabled) {
			return false;
		}

		runOnActivityUiThread(() -> showAppOpenInternal(slot));
		return true;
	}


	@UsedByGodot
	public boolean show_rewarded(String slotKey, String unitId) {
		SlotConfig slot = resolveSlot(slotKey, unitId, "rewarded");
		if (slot == null || !slot.enabled) {
			return false;
		}

		runOnActivityUiThread(() -> showRewardedInternal(slot));
		return true;
	}


	@UsedByGodot
	public boolean show_interstitial(String slotKey, String unitId) {
		SlotConfig slot = resolveSlot(slotKey, unitId, "interstitial");
		if (slot == null || !slot.enabled) {
			return false;
		}

		runOnActivityUiThread(() -> showInterstitialInternal(slot));
		return true;
	}


	private void parseRuntimeConfig(JSONObject rootConfig) {
		appOpenSlots.clear();
		rewardedSlots.clear();
		interstitialSlots.clear();
		appOpenAds.clear();
		rewardedAds.clear();
		interstitialAds.clear();
		appOpenLoading.clear();
		rewardedLoading.clear();
		interstitialLoading.clear();
		appOpenLoadTimes.clear();
		rewardedEarned.clear();
		pendingAppOpenShowSlot = "";
		pendingRewardedShowSlot = "";
		pendingInterstitialShowSlot = "";
		testDeviceIds.clear();

		JSONObject platformConfig = rootConfig.optJSONObject("platforms");
		JSONObject androidConfig = platformConfig != null ? platformConfig.optJSONObject("android") : null;
		consentEnabled = androidConfig != null && androidConfig.optBoolean("consent_enabled", false);

		if (androidConfig != null) {
			JSONArray deviceIds = androidConfig.optJSONArray("test_device_ids");
			if (deviceIds != null) {
				for (int index = 0; index < deviceIds.length(); index++) {
					String deviceId = deviceIds.optString(index, "").trim();
					if (!deviceId.isEmpty()) {
						testDeviceIds.add(deviceId);
					}
				}
			}
		}

		JSONObject slots = rootConfig.optJSONObject("slots");
		if (slots == null) {
			return;
		}

		JSONArray names = slots.names();
		if (names == null) {
			return;
		}

		for (int index = 0; index < names.length(); index++) {
			String slotKey = names.optString(index, "").trim();
			if (slotKey.isEmpty()) {
				continue;
			}

			JSONObject slotJson = slots.optJSONObject(slotKey);
			if (slotJson == null) {
				continue;
			}

			SlotConfig slot = new SlotConfig(
				slotKey,
				slotJson.optString("format", "").trim(),
				slotJson.optString("unit_id", "").trim(),
				slotJson.optBoolean("enabled", false)
			);

			if ("app_open".equals(slot.format)) {
				appOpenSlots.put(slotKey, slot);
			} else if ("rewarded".equals(slot.format)) {
				rewardedSlots.put(slotKey, slot);
			} else if ("interstitial".equals(slot.format)) {
				interstitialSlots.put(slotKey, slot);
			}
		}
	}


	private void startConsentFlow() {
		Activity activity = getActivity();
		if (activity == null) {
			emitConsentStatus("error", "Activity unavailable for consent flow.");
			return;
		}

		consentInformation = UserMessagingPlatform.getConsentInformation(activity);
		ConsentRequestParameters requestParameters = new ConsentRequestParameters.Builder().build();

		consentInformation.requestConsentInfoUpdate(
			activity,
			requestParameters,
			() -> UserMessagingPlatform.loadAndShowConsentFormIfRequired(
				activity,
				formError -> {
					if (consentInformation != null && consentInformation.canRequestAds()) {
						String detail = formError == null
							? "Consent flow finished and ads can be requested."
							: "Consent form returned a warning but ads can be requested: " + formError.getMessage();
						emitConsentStatus("granted", detail);
						initializeMobileAdsIfNeeded(null);
						return;
					}

					if (formError != null) {
						emitConsentStatus("error", "Consent form failed: " + formError.getMessage());
					} else {
						emitConsentStatus("declined", "Consent flow finished without ad consent.");
					}
				}
			),
			formError -> {
				if (consentInformation != null && consentInformation.canRequestAds()) {
					emitConsentStatus("granted", "Consent info update failed but ads can still be requested: " + formError.getMessage());
					initializeMobileAdsIfNeeded(null);
					return;
				}
				emitConsentStatus("error", "Consent info update failed: " + formError.getMessage());
			}
		);
	}


	private void initializeMobileAdsIfNeeded(@Nullable Runnable onReady) {
		if (!canRequestAds()) {
			return;
		}

		if (onReady != null) {
			pendingInitializationActions.add(onReady);
		}

		applyRequestConfiguration();
		if (adsInitialized) {
			flushInitializationActions();
			preloadConfiguredAdsIfPossible();
			return;
		}
		if (adsInitializing) {
			return;
		}

		Activity activity = getActivity();
		if (activity == null) {
			emitConsentStatus("error", "Activity unavailable for Mobile Ads initialization.");
			return;
		}

		adsInitializing = true;
		MobileAds.initialize(activity, initializationStatus -> {
			adsInitializing = false;
			adsInitialized = true;
			flushInitializationActions();
			preloadConfiguredAdsIfPossible();
		});
	}


	private void flushInitializationActions() {
		if (pendingInitializationActions.isEmpty()) {
			return;
		}

		List<Runnable> actions = new ArrayList<>(pendingInitializationActions);
		pendingInitializationActions.clear();
		for (Runnable action : actions) {
			action.run();
		}
	}


	private void preloadConfiguredAdsIfPossible() {
		if (!adsInitialized || !canRequestAds()) {
			return;
		}

		for (SlotConfig slot : rewardedSlots.values()) {
			if (slot.enabled) {
				loadRewarded(slot, false);
			}
		}
		for (SlotConfig slot : appOpenSlots.values()) {
			if (slot.enabled) {
				loadAppOpen(slot, false);
			}
		}
		for (SlotConfig slot : interstitialSlots.values()) {
			if (slot.enabled) {
				loadInterstitial(slot, false);
			}
		}
	}


	private void showAppOpenInternal(SlotConfig slot) {
		if (!slot.enabled) {
			emitAppOpenFailed(slot.slotKey, "slot_disabled");
			return;
		}
		if (TextUtils.isEmpty(slot.unitId)) {
			emitAppOpenFailed(slot.slotKey, "missing_unit_id");
			return;
		}
		if (consentEnabled && !canRequestAds()) {
			emitAppOpenFailed(slot.slotKey, "consent_blocked");
			return;
		}
		if (isAnyFullscreenAdPending() && !slot.slotKey.equals(pendingAppOpenShowSlot)) {
			emitAppOpenFailed(slot.slotKey, "busy");
			return;
		}

		pendingAppOpenShowSlot = slot.slotKey;
		initializeMobileAdsIfNeeded(() -> showAppOpenWhenReady(slot));
	}


	private void showAppOpenWhenReady(SlotConfig slot) {
		if (!slot.slotKey.equals(pendingAppOpenShowSlot)) {
			return;
		}
		if (!canRequestAds()) {
			pendingAppOpenShowSlot = "";
			emitAppOpenFailed(slot.slotKey, "consent_blocked");
			return;
		}

		AppOpenAd appOpenAd = appOpenAds.get(slot.slotKey);
		if (isAppOpenAdAvailable(slot.slotKey) && appOpenAd != null) {
			presentAppOpen(slot, appOpenAd);
			return;
		}

		loadAppOpen(slot, true);
	}


	private void loadAppOpen(SlotConfig slot, boolean showOnLoad) {
		if (!adsInitialized) {
			initializeMobileAdsIfNeeded(() -> loadAppOpen(slot, showOnLoad));
			return;
		}
		if (!slot.enabled || TextUtils.isEmpty(slot.unitId)) {
			if (showOnLoad) {
				pendingAppOpenShowSlot = "";
				emitAppOpenFailed(slot.slotKey, "invalid_slot");
			}
			return;
		}

		if (isAppOpenAdAvailable(slot.slotKey)) {
			if (showOnLoad) {
				AppOpenAd cachedAd = appOpenAds.get(slot.slotKey);
				if (cachedAd != null) {
					presentAppOpen(slot, cachedAd);
				}
			}
			return;
		}

		if (Boolean.TRUE.equals(appOpenLoading.get(slot.slotKey))) {
			return;
		}

		Activity activity = getActivity();
		if (activity == null) {
			if (showOnLoad) {
				pendingAppOpenShowSlot = "";
				emitAppOpenFailed(slot.slotKey, "activity_missing");
			}
			return;
		}

		appOpenLoading.put(slot.slotKey, true);
		AppOpenAd.load(
			activity,
			slot.unitId,
			new AdRequest.Builder().build(),
			new AppOpenAd.AppOpenAdLoadCallback() {
				@Override
				public void onAdLoaded(@NonNull AppOpenAd appOpenAd) {
					appOpenLoading.remove(slot.slotKey);
					appOpenAds.put(slot.slotKey, appOpenAd);
					appOpenLoadTimes.put(slot.slotKey, System.currentTimeMillis());
					bindAppOpenCallbacks(slot, appOpenAd);
					if (slot.slotKey.equals(pendingAppOpenShowSlot)) {
						presentAppOpen(slot, appOpenAd);
					}
				}

				@Override
				public void onAdFailedToLoad(@NonNull LoadAdError loadAdError) {
					appOpenLoading.remove(slot.slotKey);
					appOpenAds.remove(slot.slotKey);
					appOpenLoadTimes.remove(slot.slotKey);
					if (slot.slotKey.equals(pendingAppOpenShowSlot)) {
						pendingAppOpenShowSlot = "";
						emitAppOpenFailed(slot.slotKey, "load_failed:" + loadAdError.getCode());
					}
					Log.w(TAG, "App open load failed for " + slot.slotKey + ": " + loadAdError.getMessage());
				}
			}
		);
	}


	private void bindAppOpenCallbacks(SlotConfig slot, AppOpenAd appOpenAd) {
		appOpenAd.setFullScreenContentCallback(new FullScreenContentCallback() {
			@Override
			public void onAdDismissedFullScreenContent() {
				appOpenAds.remove(slot.slotKey);
				appOpenLoadTimes.remove(slot.slotKey);
				appOpenLoading.remove(slot.slotKey);
				if (slot.slotKey.equals(pendingAppOpenShowSlot)) {
					pendingAppOpenShowSlot = "";
				}
				emitSignalOnMain("app_open_closed", slot.slotKey);
				loadAppOpen(slot, false);
			}

			@Override
			public void onAdFailedToShowFullScreenContent(@NonNull AdError adError) {
				appOpenAds.remove(slot.slotKey);
				appOpenLoadTimes.remove(slot.slotKey);
				appOpenLoading.remove(slot.slotKey);
				if (slot.slotKey.equals(pendingAppOpenShowSlot)) {
					pendingAppOpenShowSlot = "";
				}
				emitAppOpenFailed(slot.slotKey, "show_failed:" + adError.getCode());
				loadAppOpen(slot, false);
			}
		});
	}


	private void presentAppOpen(SlotConfig slot, AppOpenAd appOpenAd) {
		Activity activity = getActivity();
		if (activity == null) {
			pendingAppOpenShowSlot = "";
			emitAppOpenFailed(slot.slotKey, "activity_missing");
			return;
		}

		appOpenAd.show(activity);
	}


	private void showRewardedInternal(SlotConfig slot) {
		if (!slot.enabled) {
			emitRewardedFailed(slot.slotKey, "slot_disabled");
			return;
		}
		if (TextUtils.isEmpty(slot.unitId)) {
			emitRewardedFailed(slot.slotKey, "missing_unit_id");
			return;
		}
		if (consentEnabled && !canRequestAds()) {
			emitRewardedFailed(slot.slotKey, "consent_blocked");
			return;
		}
		if (!pendingRewardedShowSlot.isEmpty() && !pendingRewardedShowSlot.equals(slot.slotKey)) {
			emitRewardedFailed(slot.slotKey, "busy");
			return;
		}

		pendingRewardedShowSlot = slot.slotKey;
		initializeMobileAdsIfNeeded(() -> showRewardedWhenReady(slot));
	}


	private void showRewardedWhenReady(SlotConfig slot) {
		if (!slot.slotKey.equals(pendingRewardedShowSlot)) {
			return;
		}
		if (!canRequestAds()) {
			pendingRewardedShowSlot = "";
			emitRewardedFailed(slot.slotKey, "consent_blocked");
			return;
		}

		RewardedAd rewardedAd = rewardedAds.get(slot.slotKey);
		if (rewardedAd != null) {
			presentRewarded(slot, rewardedAd);
			return;
		}

		loadRewarded(slot, true);
	}


	private void loadRewarded(SlotConfig slot, boolean showOnLoad) {
		if (!adsInitialized) {
			initializeMobileAdsIfNeeded(() -> loadRewarded(slot, showOnLoad));
			return;
		}
		if (!slot.enabled || TextUtils.isEmpty(slot.unitId)) {
			if (showOnLoad) {
				pendingRewardedShowSlot = "";
				emitRewardedFailed(slot.slotKey, "invalid_slot");
			}
			return;
		}

		RewardedAd cachedAd = rewardedAds.get(slot.slotKey);
		if (cachedAd != null) {
			if (showOnLoad) {
				presentRewarded(slot, cachedAd);
			}
			return;
		}
		if (Boolean.TRUE.equals(rewardedLoading.get(slot.slotKey))) {
			return;
		}

		Activity activity = getActivity();
		if (activity == null) {
			if (showOnLoad) {
				pendingRewardedShowSlot = "";
				emitRewardedFailed(slot.slotKey, "activity_missing");
			}
			return;
		}

		rewardedLoading.put(slot.slotKey, true);
		RewardedAd.load(
			activity,
			slot.unitId,
			new AdRequest.Builder().build(),
			new RewardedAdLoadCallback() {
				@Override
				public void onAdLoaded(@NonNull RewardedAd rewardedAd) {
					rewardedLoading.remove(slot.slotKey);
					rewardedAds.put(slot.slotKey, rewardedAd);
					bindRewardedCallbacks(slot, rewardedAd);
					if (slot.slotKey.equals(pendingRewardedShowSlot)) {
						presentRewarded(slot, rewardedAd);
					}
				}

				@Override
				public void onAdFailedToLoad(@NonNull LoadAdError loadAdError) {
					rewardedLoading.remove(slot.slotKey);
					rewardedAds.remove(slot.slotKey);
					if (slot.slotKey.equals(pendingRewardedShowSlot)) {
						pendingRewardedShowSlot = "";
						emitRewardedFailed(slot.slotKey, "load_failed:" + loadAdError.getCode());
					}
					Log.w(TAG, "Rewarded load failed for " + slot.slotKey + ": " + loadAdError.getMessage());
				}
			}
		);
	}


	private void bindRewardedCallbacks(SlotConfig slot, RewardedAd rewardedAd) {
		rewardedAd.setFullScreenContentCallback(new FullScreenContentCallback() {
			@Override
			public void onAdDismissedFullScreenContent() {
				rewardedAds.remove(slot.slotKey);
				rewardedLoading.remove(slot.slotKey);
				boolean earnedReward = Boolean.TRUE.equals(rewardedEarned.remove(slot.slotKey));
				if (slot.slotKey.equals(pendingRewardedShowSlot)) {
					pendingRewardedShowSlot = "";
				}
				if (earnedReward) {
					emitSignalOnMain("rewarded_completed", slot.slotKey);
				} else {
					emitRewardedFailed(slot.slotKey, "dismissed_before_reward");
				}
				loadRewarded(slot, false);
			}

			@Override
			public void onAdFailedToShowFullScreenContent(@NonNull AdError adError) {
				rewardedAds.remove(slot.slotKey);
				rewardedLoading.remove(slot.slotKey);
				rewardedEarned.remove(slot.slotKey);
				if (slot.slotKey.equals(pendingRewardedShowSlot)) {
					pendingRewardedShowSlot = "";
				}
				emitRewardedFailed(slot.slotKey, "show_failed:" + adError.getCode());
				loadRewarded(slot, false);
			}
		});
	}


	private void presentRewarded(SlotConfig slot, RewardedAd rewardedAd) {
		Activity activity = getActivity();
		if (activity == null) {
			pendingRewardedShowSlot = "";
			emitRewardedFailed(slot.slotKey, "activity_missing");
			return;
		}

		rewardedEarned.put(slot.slotKey, false);
		rewardedAd.show(activity, rewardItem -> rewardedEarned.put(slot.slotKey, true));
	}


	private void showInterstitialInternal(SlotConfig slot) {
		if (!slot.enabled) {
			emitInterstitialFailed(slot.slotKey, "slot_disabled");
			return;
		}
		if (TextUtils.isEmpty(slot.unitId)) {
			emitInterstitialFailed(slot.slotKey, "missing_unit_id");
			return;
		}
		if (consentEnabled && !canRequestAds()) {
			emitInterstitialFailed(slot.slotKey, "consent_blocked");
			return;
		}
		if (!pendingInterstitialShowSlot.isEmpty() && !pendingInterstitialShowSlot.equals(slot.slotKey)) {
			emitInterstitialFailed(slot.slotKey, "busy");
			return;
		}

		pendingInterstitialShowSlot = slot.slotKey;
		initializeMobileAdsIfNeeded(() -> showInterstitialWhenReady(slot));
	}


	private void showInterstitialWhenReady(SlotConfig slot) {
		if (!slot.slotKey.equals(pendingInterstitialShowSlot)) {
			return;
		}
		if (!canRequestAds()) {
			pendingInterstitialShowSlot = "";
			emitInterstitialFailed(slot.slotKey, "consent_blocked");
			return;
		}

		InterstitialAd interstitialAd = interstitialAds.get(slot.slotKey);
		if (interstitialAd != null) {
			presentInterstitial(slot, interstitialAd);
			return;
		}

		loadInterstitial(slot, true);
	}


	private void loadInterstitial(SlotConfig slot, boolean showOnLoad) {
		if (!adsInitialized) {
			initializeMobileAdsIfNeeded(() -> loadInterstitial(slot, showOnLoad));
			return;
		}
		if (!slot.enabled || TextUtils.isEmpty(slot.unitId)) {
			if (showOnLoad) {
				pendingInterstitialShowSlot = "";
				emitInterstitialFailed(slot.slotKey, "invalid_slot");
			}
			return;
		}

		InterstitialAd cachedAd = interstitialAds.get(slot.slotKey);
		if (cachedAd != null) {
			if (showOnLoad) {
				presentInterstitial(slot, cachedAd);
			}
			return;
		}
		if (Boolean.TRUE.equals(interstitialLoading.get(slot.slotKey))) {
			return;
		}

		Activity activity = getActivity();
		if (activity == null) {
			if (showOnLoad) {
				pendingInterstitialShowSlot = "";
				emitInterstitialFailed(slot.slotKey, "activity_missing");
			}
			return;
		}

		interstitialLoading.put(slot.slotKey, true);
		InterstitialAd.load(
			activity,
			slot.unitId,
			new AdRequest.Builder().build(),
			new InterstitialAdLoadCallback() {
				@Override
				public void onAdLoaded(@NonNull InterstitialAd interstitialAd) {
					interstitialLoading.remove(slot.slotKey);
					interstitialAds.put(slot.slotKey, interstitialAd);
					bindInterstitialCallbacks(slot, interstitialAd);
					if (slot.slotKey.equals(pendingInterstitialShowSlot)) {
						presentInterstitial(slot, interstitialAd);
					}
				}

				@Override
				public void onAdFailedToLoad(@NonNull LoadAdError loadAdError) {
					interstitialLoading.remove(slot.slotKey);
					interstitialAds.remove(slot.slotKey);
					if (slot.slotKey.equals(pendingInterstitialShowSlot)) {
						pendingInterstitialShowSlot = "";
						emitInterstitialFailed(slot.slotKey, "load_failed:" + loadAdError.getCode());
					}
					Log.w(TAG, "Interstitial load failed for " + slot.slotKey + ": " + loadAdError.getMessage());
				}
			}
		);
	}


	private void bindInterstitialCallbacks(SlotConfig slot, InterstitialAd interstitialAd) {
		interstitialAd.setFullScreenContentCallback(new FullScreenContentCallback() {
			@Override
			public void onAdDismissedFullScreenContent() {
				interstitialAds.remove(slot.slotKey);
				interstitialLoading.remove(slot.slotKey);
				if (slot.slotKey.equals(pendingInterstitialShowSlot)) {
					pendingInterstitialShowSlot = "";
				}
				emitSignalOnMain("interstitial_closed", slot.slotKey);
				loadInterstitial(slot, false);
			}

			@Override
			public void onAdFailedToShowFullScreenContent(@NonNull AdError adError) {
				interstitialAds.remove(slot.slotKey);
				interstitialLoading.remove(slot.slotKey);
				if (slot.slotKey.equals(pendingInterstitialShowSlot)) {
					pendingInterstitialShowSlot = "";
				}
				emitInterstitialFailed(slot.slotKey, "show_failed:" + adError.getCode());
				loadInterstitial(slot, false);
			}
		});
	}


	private void presentInterstitial(SlotConfig slot, InterstitialAd interstitialAd) {
		Activity activity = getActivity();
		if (activity == null) {
			pendingInterstitialShowSlot = "";
			emitInterstitialFailed(slot.slotKey, "activity_missing");
			return;
		}

		interstitialAd.show(activity);
	}


	private void applyRequestConfiguration() {
		RequestConfiguration.Builder requestConfiguration = MobileAds.getRequestConfiguration().toBuilder();
		requestConfiguration.setTestDeviceIds(new ArrayList<>(testDeviceIds));
		MobileAds.setRequestConfiguration(requestConfiguration.build());
	}


	private boolean canRequestAds() {
		return !consentEnabled || (consentInformation != null && consentInformation.canRequestAds());
	}


	private void emitConsentStatus(String status, String detail) {
		emitSignalOnMain("consent_result", status, detail);
		emitSignalOnMain("consent_status_changed", status);
	}


	private void emitRewardedFailed(String slotKey, String reason) {
		emitSignalOnMain("rewarded_failed", slotKey, reason);
	}


	private void emitAppOpenFailed(String slotKey, String reason) {
		emitSignalOnMain("app_open_failed", slotKey, reason);
	}


	private void emitInterstitialFailed(String slotKey, String reason) {
		emitSignalOnMain("interstitial_failed", slotKey, reason);
	}


	private void emitSignalOnMain(String signalName, Object... arguments) {
		mainHandler.post(() -> emitSignal(signalName, arguments));
	}


	private void runOnActivityUiThread(Runnable action) {
		Activity activity = getActivity();
		if (activity != null) {
			activity.runOnUiThread(action);
		} else {
			mainHandler.post(action);
		}
	}


	@Nullable
	private SlotConfig resolveSlot(String slotKey, String unitId, String expectedFormat) {
		String normalizedSlotKey = slotKey == null ? "" : slotKey.trim();
		if (normalizedSlotKey.isEmpty()) {
			return null;
		}

		Map<String, SlotConfig> sourceMap;
		if ("app_open".equals(expectedFormat)) {
			sourceMap = appOpenSlots;
		} else if ("rewarded".equals(expectedFormat)) {
			sourceMap = rewardedSlots;
		} else {
			sourceMap = interstitialSlots;
		}
		SlotConfig slot = sourceMap.get(normalizedSlotKey);
		if (slot == null) {
			String normalizedUnitId = unitId == null ? "" : unitId.trim();
			if (normalizedUnitId.isEmpty()) {
				return null;
			}
			slot = new SlotConfig(normalizedSlotKey, expectedFormat, normalizedUnitId, true);
			sourceMap.put(normalizedSlotKey, slot);
		} else if (!TextUtils.isEmpty(unitId)) {
			slot.unitId = unitId.trim();
		}
		return slot;
	}


	private boolean isAnyFullscreenAdPending() {
		return !pendingAppOpenShowSlot.isEmpty() || !pendingRewardedShowSlot.isEmpty() || !pendingInterstitialShowSlot.isEmpty();
	}


	private boolean isAppOpenAdAvailable(String slotKey) {
		if (!appOpenAds.containsKey(slotKey)) {
			return false;
		}
		Long loadTime = appOpenLoadTimes.get(slotKey);
		if (loadTime == null) {
			return false;
		}
		if (System.currentTimeMillis() - loadTime.longValue() >= APP_OPEN_MAX_AGE_MS) {
			appOpenAds.remove(slotKey);
			appOpenLoadTimes.remove(slotKey);
			return false;
		}
		return true;
	}


	private static final class SlotConfig {
		final String slotKey;
		final String format;
		boolean enabled;
		String unitId;


		SlotConfig(String slotKey, String format, String unitId, boolean enabled) {
			this.slotKey = slotKey;
			this.format = format;
			this.unitId = unitId;
			this.enabled = enabled;
		}
	}
}
