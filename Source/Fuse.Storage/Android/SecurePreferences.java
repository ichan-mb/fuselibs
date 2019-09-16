package com.fuse.securepreferences;

import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.preference.PreferenceManager;
import android.provider.Settings;
import android.text.TextUtils;
import android.util.Base64;
import android.util.Log;
import com.tozny.crypto.android.AesCbcWithIntegrity;
import java.io.UnsupportedEncodingException;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;


public class SecurePreferences implements SharedPreferences {

    private static final String TAG = SecurePreferences.class.getName();
    private SharedPreferences sharedPreferences;
    private AesCbcWithIntegrity.SecretKeys keys;
    private String salt;
    private static boolean mLoggingEnabled = false;
    private String sharedPreferenceFilename;


    public SecurePreferences(Context context) {
        this(context, "", null);
    }

    public SecurePreferences(Context context, String salt) {
        this(context, null, "", salt, null);
    }

    public SecurePreferences(Context context, final String password, final String sharedPreferenceFilename) {
        this(context, password, null, sharedPreferenceFilename);
    }

    public SecurePreferences(Context context, final String password, final String salt, final String sharedPreferenceFilename) {
        this(context, null, password, salt, sharedPreferenceFilename);
    }

    private SecurePreferences(Context context, final AesCbcWithIntegrity.SecretKeys secretKey, final String password, final String salt, final String sharedPreferenceFilename) {
        if (sharedPreferences == null) {
            sharedPreferences = getSharedPreferenceFile(context, sharedPreferenceFilename);
        }

        this.salt = salt;

        if (secretKey != null) {
            keys = secretKey;
        } else if (TextUtils.isEmpty(password)) {
            try {
                final String key = generateAesKeyName(context);

                String keyAsString = sharedPreferences.getString(key, null);
                if (keyAsString == null) {
                    keys = AesCbcWithIntegrity.generateKey();
                    //saving new key
                    boolean committed = sharedPreferences.edit().putString(key, keys.toString()).commit();
                    if (!committed) {
                        Log.w(TAG, "Key not committed to prefs");
                    }
                } else {
                    keys = AesCbcWithIntegrity.keys(keyAsString);
                }

                if (keys == null) {
                    throw new GeneralSecurityException("Problem generating Key");
                }

            } catch (GeneralSecurityException e) {
                if (mLoggingEnabled) {
                    Log.e(TAG, "Error init:" + e.getMessage());
                }
                throw new IllegalStateException(e);
            }
        } else {
            try {
                final byte[] saltBytes = getSalt(context).getBytes();
                keys = AesCbcWithIntegrity.generateKeyFromPassword(password, saltBytes);

                if (keys == null) {
                    throw new GeneralSecurityException("Problem generating Key From Password");
                }
            } catch (GeneralSecurityException e) {
                if (mLoggingEnabled) {
                    Log.e(TAG, "Error init using user password:" + e.getMessage());
                }
                throw new IllegalStateException(e);
            }
        }
    }


    private SharedPreferences getSharedPreferenceFile(Context context, String prefFilename) {
        this.sharedPreferenceFilename = prefFilename;

        if (TextUtils.isEmpty(prefFilename)) {
            return PreferenceManager
                    .getDefaultSharedPreferences(context);
        } else {
            return context.getSharedPreferences(prefFilename, Context.MODE_PRIVATE);
        }
    }

    public void destroyKeys() {
        keys = null;
    }

    @SuppressLint("HardwareIds")
    private static String getDeviceSerialNumber(Context context) {
        try {
            String deviceSerial = (String) Build.class.getField("SERIAL").get(
                    null);
            if (TextUtils.isEmpty(deviceSerial)) {
                return Settings.Secure.getString(
                        context.getContentResolver(),
                        Settings.Secure.ANDROID_ID);
            } else {
                return deviceSerial;
            }
        } catch (Exception ignored) {
            return Settings.Secure.getString(context.getContentResolver(),
                    Settings.Secure.ANDROID_ID);
        }
    }

    private String getSalt(Context context) {
        if (TextUtils.isEmpty(this.salt)) {
            return getDeviceSerialNumber(context);
        } else {
            return this.salt;
        }
    }

    private String generateAesKeyName(Context context) throws GeneralSecurityException {
        final String password = context.getPackageName();
        final byte[] salt = getSalt(context).getBytes();
        AesCbcWithIntegrity.SecretKeys generatedKeyName = AesCbcWithIntegrity.generateKeyFromPassword(password, salt);

        return hashPreferenceKey(generatedKeyName.toString());
    }

    public static String hashPreferenceKey(String prefKey) {
        final MessageDigest digest;
        try {
            digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = prefKey.getBytes("UTF-8");
            digest.update(bytes, 0, bytes.length);

            return Base64.encodeToString(digest.digest(), AesCbcWithIntegrity.BASE64_FLAGS);

        } catch (NoSuchAlgorithmException | UnsupportedEncodingException e) {
            if (mLoggingEnabled) {
                Log.w(TAG, "Problem generating hash", e);
            }
        }
        return null;
    }


    private String encrypt(String cleartext) {
        if (TextUtils.isEmpty(cleartext)) {
            return cleartext;
        }
        try {
            return AesCbcWithIntegrity.encrypt(cleartext, keys).toString();
        } catch (GeneralSecurityException e) {
            if (mLoggingEnabled) {
                Log.w(TAG, "encrypt", e);
            }
            return null;
        } catch (UnsupportedEncodingException e) {
            if (mLoggingEnabled) {
                Log.w(TAG, "encrypt", e);
            }
        }
        return null;
    }

    private String decrypt(final String ciphertext) {
        if (TextUtils.isEmpty(ciphertext)) {
            return ciphertext;
        }
        try {
            AesCbcWithIntegrity.CipherTextIvMac cipherTextIvMac = new AesCbcWithIntegrity.CipherTextIvMac(ciphertext);

            return AesCbcWithIntegrity.decryptString(cipherTextIvMac, keys);
        } catch (GeneralSecurityException | UnsupportedEncodingException e) {
            if (mLoggingEnabled) {
                Log.w(TAG, "decrypt", e);
            }
        }
        return null;
    }

    @Override
    public Map<String, String> getAll() {
        final Map<String, ?> encryptedMap = sharedPreferences.getAll();
        final Map<String, String> decryptedMap = new HashMap<String, String>(
                encryptedMap.size());
        for (Entry<String, ?> entry : encryptedMap.entrySet()) {
            try {
                Object cipherText = entry.getValue();
                if (cipherText != null && !cipherText.equals(keys.toString())) {
                    decryptedMap.put(entry.getKey(),
                            decrypt(cipherText.toString()));
                }
            } catch (Exception e) {
                if (mLoggingEnabled) {
                    Log.w(TAG, "error during getAll", e);
                }
                decryptedMap.put(entry.getKey(),
                        entry.getValue().toString());
            }
        }
        return decryptedMap;
    }

    @Override
    @TargetApi(Build.VERSION_CODES.HONEYCOMB)
    public Set<String> getStringSet(String key, Set<String> defaultValues) {
        final Set<String> encryptedSet = sharedPreferences.getStringSet(
                SecurePreferences.hashPreferenceKey(key), null);
        if (encryptedSet == null) {
            return defaultValues;
        }
        final Set<String> decryptedSet = new HashSet<String>(
                encryptedSet.size());
        for (String encryptedValue : encryptedSet) {
            decryptedSet.add(decrypt(encryptedValue));
        }
        return decryptedSet;
    }

    @Override
    public String getString(String key, String defaultValue) {
        final String encryptedValue = sharedPreferences.getString(
                SecurePreferences.hashPreferenceKey(key), null);

        String decryptedValue = decrypt(encryptedValue);
        if (encryptedValue != null && decryptedValue != null) {
            return decryptedValue;
        } else {
            return defaultValue;
        }
    }

    @Override
    public int getInt(String key, int defaultValue) {
        final String encryptedValue = sharedPreferences.getString(
                SecurePreferences.hashPreferenceKey(key), null);
        if (encryptedValue == null) {
            return defaultValue;
        }
        try {
            return Integer.parseInt(decrypt(encryptedValue));
        } catch (NumberFormatException e) {
            throw new ClassCastException(e.getMessage());
        }
    }

    @Override
    public float getFloat(String key, float defaultValue) {
        final String encryptedValue = sharedPreferences.getString(
                SecurePreferences.hashPreferenceKey(key), null);
        if (encryptedValue == null) {
            return defaultValue;
        }
        try {
            return Float.parseFloat(decrypt(encryptedValue));
        } catch (NumberFormatException e) {
            throw new ClassCastException(e.getMessage());
        }
    }

    @Override
    public long getLong(String key, long defaultValue) {
        final String encryptedValue = sharedPreferences.getString(
                SecurePreferences.hashPreferenceKey(key), null);
        if (encryptedValue == null) {
            return defaultValue;
        }
        try {
            return Long.parseLong(decrypt(encryptedValue));
        } catch (NumberFormatException e) {
            throw new ClassCastException(e.getMessage());
        }
    }

    @Override
    public boolean getBoolean(String key, boolean defaultValue) {
        final String encryptedValue = sharedPreferences.getString(
                SecurePreferences.hashPreferenceKey(key), null);
        if (encryptedValue == null) {
            return defaultValue;
        }
        try {
            return Boolean.parseBoolean(decrypt(encryptedValue));
        } catch (NumberFormatException e) {
            throw new ClassCastException(e.getMessage());
        }
    }

    @Override
    public boolean contains(String key) {
        return sharedPreferences.contains(SecurePreferences.hashPreferenceKey(key));
    }

    @Override
    public void registerOnSharedPreferenceChangeListener(
            final OnSharedPreferenceChangeListener listener) {
        sharedPreferences
                .registerOnSharedPreferenceChangeListener(listener);
    }

    @Override
    public void unregisterOnSharedPreferenceChangeListener(
            OnSharedPreferenceChangeListener listener) {
        sharedPreferences
                .unregisterOnSharedPreferenceChangeListener(listener);
    }

    @Override
    public Editor edit() {
        return new Editor();
    }

    public final class Editor implements SharedPreferences.Editor {
        private SharedPreferences.Editor mEditor;

        private Editor() {
            mEditor = sharedPreferences.edit();
        }

        @Override
        @TargetApi(Build.VERSION_CODES.HONEYCOMB)
        public SharedPreferences.Editor putStringSet(String key,
                                                     Set<String> values) {
            final Set<String> encryptedValues = new HashSet<String>(
                    values.size());
            for (String value : values) {
                encryptedValues.add(encrypt(value));
            }
            mEditor.putStringSet(SecurePreferences.hashPreferenceKey(key),
                    encryptedValues);
            return this;
        }

        @Override
        public SharedPreferences.Editor putString(String key, String value) {
            mEditor.putString(SecurePreferences.hashPreferenceKey(key),
                    encrypt(value));
            return this;
        }

        @Override
        public SharedPreferences.Editor putInt(String key, int value) {
            mEditor.putString(SecurePreferences.hashPreferenceKey(key),
                    encrypt(Integer.toString(value)));
            return this;
        }

        @Override
        public SharedPreferences.Editor putFloat(String key, float value) {
            mEditor.putString(SecurePreferences.hashPreferenceKey(key),
                    encrypt(Float.toString(value)));
            return this;
        }

        @Override
        public SharedPreferences.Editor putLong(String key, long value) {
            mEditor.putString(SecurePreferences.hashPreferenceKey(key),
                    encrypt(Long.toString(value)));
            return this;
        }

        @Override
        public SharedPreferences.Editor putBoolean(String key, boolean value) {
            mEditor.putString(SecurePreferences.hashPreferenceKey(key),
                    encrypt(Boolean.toString(value)));
            return this;
        }

        @Override
        public SharedPreferences.Editor remove(String key) {
            mEditor.remove(SecurePreferences.hashPreferenceKey(key));
            return this;
        }

        @Override
        public SharedPreferences.Editor clear() {
            mEditor.clear();
            return this;
        }

        @Override
        public boolean commit() {
            return mEditor.commit();
        }

        @Override
        @TargetApi(Build.VERSION_CODES.GINGERBREAD)
        public void apply() {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.GINGERBREAD) {
                mEditor.apply();
            } else {
                commit();
            }
        }
    }
}