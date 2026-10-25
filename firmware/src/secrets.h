/**
 * secrets.h — Cafeana Kitchen Terminal credentials
 *
 * ⚠️  THIS FILE IS GITIGNORED. Never commit real credentials.
 *
 * 1. Copy this file: cp secrets.h.example secrets.h
 * 2. Fill in your real values from the Firebase Console.
 * 3. The main.cpp includes this file automatically.
 *
 * How to find these values:
 *   FIREBASE_API_KEY → Firebase Console → Project Settings → General → "Web API key"
 *   FIREBASE_PROJECT → Firebase Console → Project Settings → General → "Project ID"
 *   DEVICE_EMAIL     → The email you set when creating the device account (api-contract.md §Device Account Setup)
 *   DEVICE_PASSWORD  → The strong random password you generated for that account
 */

#pragma once

#define FIREBASE_API_KEY   "AIzaSyCdBnSkIKPACwuQb_FBOhgAJSN-tOzUTvo"
#define FIREBASE_PROJECT   "cafeana-7fa42"
#define DEVICE_EMAIL       "terminal@cafeana.internal"
#define DEVICE_PASSWORD    "cafeana1230"
