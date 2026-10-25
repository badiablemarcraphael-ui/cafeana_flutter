# Cafeana End-to-End Verification Walkthrough

The development of **Phase 1 through 7** is now complete! The code compiles without errors (only a few `avoid_print` info logs in utility scripts), and the local Flutter web server is running in the background at **http://localhost:8080**.

As requested, here is your step-by-step walkthrough to perform the final manual verification pass.

> [!NOTE]
> There are **no divergences** between the current implementation, `/docs/data-model.md`, and `/docs/api-contract.md`. The ESP32 REST calls precisely match the Firestore Security Rules (`updateMask` fields exactly align with the `diff().affectedKeys()` allowed in the rules).

---

## Part 1: Automated Seeding & Exports

1. **Seed the Database:**
   - Open **http://localhost:8080/staff** in your browser.
   - Log in with your staff account (or create one and manually update `role: "staff"` in Firestore).
   - On the Staff Dashboard, locate the **Debug: Seed DB** button and click it.
   - This script generates:
     - 3 completed orders with different totals/dates/products.
     - 2 products with stock $\le$ threshold (10), and 2 products above it.
     - 1 test customer account.
   - Verify that the Dashboard now displays metrics and recent activity.

2. **Verify CSV Exports:**
   - Navigate to the **Analytics** page and click **Export Sales Report (CSV)**.
   - Navigate to the **Inventory** page and click **Export Inventory Report (CSV)**.
   - Open the downloaded `.csv` files locally and confirm they display a clean table format with the correct columns and data.

---

## Part 2: Verify Empty States (Phase 7)

To verify the new empty states without deleting your data, follow this safe procedure:

1. Create a fresh Firebase project (or temporarily change your `lib/firebase_options.dart` to point to a blank mock project).
2. Start the app on the fresh database.
3. Check the following pages to confirm they display a friendly empty-state message instead of an infinite spinner or blank screen:
   - **Customer Menu:** (Empty category views)
   - **Customer Cart:** (Empty cart UI)
   - **Customer Order History:** (No past orders)
   - **Staff Live Queue:** (No active orders)
   - **Staff Inventory:** (No products)
   - **Staff Analytics:** (No sales data for the selected period)
   - **Staff Feedback Review:** (No feedback submitted yet)

---

## Part 3: The End-to-End Kitchen Loop (Wokwi)

Now let's wire the physical (simulated) loop.

### Setup
1. **Open the Customer App:** Open a new incognito window at `http://localhost:8080/customer/register`. Register a new account (or use the seeded one).
2. **Open the Staff App:** Keep your staff window open at `http://localhost:8080/staff/queue`.
3. **Open Wokwi:**
   - Go to [Wokwi.com](https://wokwi.com/) and create a new ESP32 project.
   - Paste the contents of `firmware/wokwi/diagram.json` and `firmware/src/main.cpp`.
   - Before running, ensure you have set your `FIREBASE_API_KEY`, `FIREBASE_PROJECT`, and device credentials in the `main.cpp` configuration block.
   - Run the simulation. The OLED should display **Idle... Waiting for orders**.

### The Walkthrough
1. **Place an Order:** In the customer app, add a couple of items to your cart and proceed to Checkout. Click **Mark as Paid (Simulated)** and confirm the order.
2. **Observe the Live Queue:**
   - Instantly, the order will appear in the Staff Live Order Queue with a status of `queued`.
3. **Observe Wokwi (Polling):**
   - Within 5 seconds (one poll cycle), the Wokwi ESP32 will pick up the order.
   - The OLED will display `** NEW ORDER **` and the order number. The buzzer will sound, and the LED will blink.
   - The order status in both the Staff and Customer apps will flip to `preparing` (because the ESP32 sent an acknowledgment PATCH).
4. **Mark as Ready:**
   - In Wokwi, click the **Push Button**.
   - The OLED will display **ORDER READY!** and clear itself.
   - **Instantly** (via Firestore snapshot listeners), both the Customer Live Tracking screen and the Staff Queue will update the status to `ready`.
5. **Complete & Feedback:**
   - In the Staff Queue (or Customer view, depending on your flow preference), mark the order as `received`/`completed`.
   - Once completed, the Customer app will prompt for feedback. Submit a 5-star rating and a comment.
   - Navigate to the **Staff Feedback Review** page and confirm your review appears at the top.

---

> [!TIP]
> All systems are running and ready for you to execute these tests. The local Flutter server is live. Let me know if you encounter any snags during the Wokwi hardware simulation!
