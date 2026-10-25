import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cafeana_app/core/models/order.dart';
import 'package:cafeana_app/core/models/product.dart';
import 'package:cafeana_app/core/models/user_profile.dart';
import 'package:cafeana_app/core/models/ingredient.dart';

Future<void> seedDatabase() async {
  final db = FirebaseFirestore.instance;

  debugPrint('Starting seed...');

  String? customerUid;
  String? ownerUid;
  String? cashierUid;
  String? kitchenUid;

  try {
    // Create auth users using a temporary app instance to avoid signing out the current user
    final tempApp = await Firebase.initializeApp(
      name: 'temp_seed_app_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
    
    Future<String?> getOrCreate(String email) async {
      try {
        final cred = await tempAuth.createUserWithEmailAndPassword(
          email: email,
          password: 'password123',
        );
        return cred.user?.uid;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          final cred = await tempAuth.signInWithEmailAndPassword(
            email: email,
            password: 'password123',
          );
          return cred.user?.uid;
        }
        debugPrint('Auth failed for $email: $e');
        return null;
      }
    }

    customerUid = await getOrCreate('customer@seed.com');
    ownerUid = await getOrCreate('owner@seed.com');
    cashierUid = await getOrCreate('cashier@seed.com');
    kitchenUid = await getOrCreate('kitchen@seed.com');

    await tempApp.delete();
  } catch (e) {
    debugPrint('Failed to setup temp auth app: $e');
  }

  customerUid ??= 'seed_customer_1';
  ownerUid ??= 'seed_owner_1';
  cashierUid ??= 'seed_cashier_1';
  kitchenUid ??= 'seed_kitchen_1';

  // 1. Create a customer and staff user if they don't exist
  await db.collection('users').doc(customerUid).set({
    'email': 'customer@seed.com',
    'role': UserRole.customer.name,
    'displayName': 'Seed Customer',
  });
  
  // Owner account
  await db.collection('users').doc(ownerUid).set({
    'email': 'owner@seed.com',
    'role': UserRole.owner.name,
    'displayName': 'Seed Owner',
  });

  // Cashier account
  await db.collection('users').doc(cashierUid).set({
    'email': 'cashier@seed.com',
    'role': UserRole.cashier.name,
    'displayName': 'Seed Cashier',
  });

  // Kitchen account
  await db.collection('users').doc(kitchenUid).set({
    'email': 'kitchen@seed.com',
    'role': UserRole.kitchen.name,
    'displayName': 'Seed Kitchen',
  });

  // 2. Create products from the actual menu
  // Mix of different categories, prices, and stock levels
  final products = [
    // Classics
    Product(
      id: 'prod_americano',
      name: 'Americano',
      price: 99.00,
      category: 'Classics',
      isAvailable: true,
      stock: 5, // low stock
    ),
    Product(
      id: 'prod_spanish_latte',
      name: 'Spanish Latte',
      price: 119.00,
      category: 'Classics',
      isAvailable: true,
      stock: 20, 
    ),
    // New Selections
    Product(
      id: 'prod_espresso_katipunero',
      name: 'Espresso Katipunero',
      price: 148.00,
      category: 'Iced Coffee',
      isAvailable: true,
      stock: 8, // low stock
    ),
    // Premiums
    Product(
      id: 'prod_caramel_macchiato',
      name: 'Caramel Macchiato',
      price: 125.00,
      category: 'Premiums',
      isAvailable: true,
      stock: 15,
    ),
    const Product(
      id: 'prod_biscoff_latte',
      itemId: 'M016',
      name: 'Biscoff Latte',
      price: 150.00,
      cost: 79.40,
      category: 'Specialty',
      isAvailable: true,
      stock: 45, // high stock
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING070', name: 'Biscoff Spread', quantity: 35, unit: 'g', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING071', name: 'Biscoff Cookie Crumble', quantity: 12, unit: 'g', unitCost: 0.37),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    // Non-Coffee
    Product(
      id: 'prod_strawberry_milk',
      name: 'Strawberry Milk',
      price: 109.00,
      category: 'Non-Coffee',
      isAvailable: true,
      stock: 30,
    ),
    Product(
      id: 'prod_matcha',
      name: 'Matcha',
      price: 109.00,
      category: 'Non-Coffee',
      isAvailable: true,
      stock: 4, // extremely low stock
    ),
    // Fizzy Drinks
    Product(
      id: 'prod_strawberry_lemonade',
      name: 'Strawberry Lemonade',
      price: 109.00,
      category: 'Fizzy Drinks',
      isAvailable: true,
      stock: 50, // high stock
    ),
  ];

  for (final p in products) {
    await db.collection('products').doc(p.id).set(p.toFirestore(), SetOptions(merge: true));
  }

  // 3. Create 3 completed orders using the new products
  final order1Items = [
    OrderItem(productId: 'prod_americano', name: 'Americano', quantity: 2, price: 99.00),
    OrderItem(productId: 'prod_strawberry_milk', name: 'Strawberry Milk', quantity: 1, price: 109.00),
  ];
  final order1 = CafeOrder(
    id: 'seed_order_1',
    orderNumber: 1001,
    customerId: customerUid,
    items: order1Items,
    total: 307.00,
    paymentStatus: PaymentStatus.paid,
    status: OrderStatus.completed,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    updatedAt: DateTime.now().subtract(const Duration(days: 2)),
  );

  final order2Items = [
    OrderItem(productId: 'prod_spanish_latte', name: 'Spanish Latte', quantity: 1, price: 119.00),
    OrderItem(productId: 'prod_biscoff_latte', name: 'Biscoff Latte', quantity: 2, price: 150.00),
  ];
  final order2 = CafeOrder(
    id: 'seed_order_2',
    orderNumber: 1002,
    customerId: customerUid,
    items: order2Items,
    total: 419.00,
    paymentStatus: PaymentStatus.paid,
    status: OrderStatus.completed,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    updatedAt: DateTime.now().subtract(const Duration(days: 1)),
  );

  final order3Items = [
    OrderItem(productId: 'prod_espresso_katipunero', name: 'Espresso Katipunero', quantity: 1, price: 148.00),
    OrderItem(productId: 'prod_matcha', name: 'Matcha', quantity: 3, price: 109.00),
    OrderItem(productId: 'prod_strawberry_lemonade', name: 'Strawberry Lemonade', quantity: 1, price: 109.00),
  ];
  final order3 = CafeOrder(
    id: 'seed_order_3',
    orderNumber: 1003,
    customerId: customerUid,
    items: order3Items,
    total: 584.00,
    paymentStatus: PaymentStatus.paid,
    status: OrderStatus.completed,
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
  );

  // Since order toFirestore() uses serverTimestamp(), we write directly without using toFirestore() 
  // to preserve historical creation dates for the analytics screens.
  
  await db.collection('orders').doc('seed_order_1').set({
    'orderNumber': order1.orderNumber,
    'customerId': order1.customerId,
    'items': order1.items.map((i) => i.toMap()).toList(),
    'total': order1.total,
    'paymentStatus': order1.paymentStatus.firestoreValue,
    'status': order1.status.firestoreValue,
    'createdAt': Timestamp.fromDate(order1.createdAt),
    'updatedAt': Timestamp.fromDate(order1.updatedAt),
  });

  await db.collection('orders').doc('seed_order_2').set({
    'orderNumber': order2.orderNumber,
    'customerId': order2.customerId,
    'items': order2.items.map((i) => i.toMap()).toList(),
    'total': order2.total,
    'paymentStatus': order2.paymentStatus.firestoreValue,
    'status': order2.status.firestoreValue,
    'createdAt': Timestamp.fromDate(order2.createdAt),
    'updatedAt': Timestamp.fromDate(order2.updatedAt),
  });

  await db.collection('orders').doc('seed_order_3').set({
    'orderNumber': order3.orderNumber,
    'customerId': order3.customerId,
    'items': order3.items.map((i) => i.toMap()).toList(),
    'total': order3.total,
    'paymentStatus': order3.paymentStatus.firestoreValue,
    'status': order3.status.firestoreValue,
    'createdAt': Timestamp.fromDate(order3.createdAt),
    'updatedAt': Timestamp.fromDate(order3.updatedAt),
  });

  // 4. Initialize global counter (Required for new orders to succeed)
  await db.collection('counters').doc('global').set({
    'nextOrderNumber': 1003,
  });

  // 5. Seed master ingredients, standard add-ons, and menu recipes
  await seedMasterInventoryAndRecipes();

  debugPrint('Seed completed!');
}

Future<void> seedAdditionalProducts() async {
  final db = FirebaseFirestore.instance;
  
  final products = [
    // Classics
    Product(id: "prod_vanilla", name: "Vanilla", category: "Classics", price: 119, stock: 20, isAvailable: true),
    Product(id: "prod_caramel_latte", name: "Caramel Latte", category: "Classics", price: 119, stock: 20, isAvailable: true),
    Product(id: "prod_french_vanilla", name: "French Vanilla", category: "Classics", price: 119, stock: 20, isAvailable: true),
    Product(id: "prod_hazelnut", name: "Hazelnut", category: "Classics", price: 119, stock: 20, isAvailable: true),
    Product(id: "prod_dirty_matcha", name: "Dirty Matcha", category: "Classics", price: 119, stock: 20, isAvailable: true),
    Product(id: "prod_cafe_latte", name: "Cafe Latte", category: "Classics", price: 99, stock: 20, isAvailable: true),
    Product(id: "prod_cappuccino", name: "Cappuccino", category: "Classics", price: 99, stock: 20, isAvailable: true),
    
    // Iced Coffee
    Product(id: "prod_toffee_nut_latte", name: "Toffee Nut Latte", category: "Iced Coffee", price: 135, stock: 20, isAvailable: true),
    Product(id: "prod_creme_brulee_latte", name: "Creme Brulee Latte", category: "Iced Coffee", price: 135, stock: 20, isAvailable: true),
    Product(id: "prod_chocodamia", name: "Chocodamia", category: "Iced Coffee", price: 140, stock: 20, isAvailable: true),
    Product(id: "prod_toasty_almonds_latte", name: "Toasty Almonds Latte", category: "Iced Coffee", price: 135, stock: 20, isAvailable: true),
    Product(id: "prod_caradamia_latte", name: "Caradamia Latte", category: "Iced Coffee", price: 140, stock: 20, isAvailable: true),
    Product(id: "prod_biscoffee", name: "Biscoffee", category: "Iced Coffee", price: 150, stock: 20, isAvailable: true),
    
    // Premiums
    Product(id: "prod_mocha", name: "Mocha", category: "Premiums", price: 125, stock: 20, isAvailable: true),
    Product(id: "prod_white_mocha", name: "White Mocha", category: "Premiums", price: 125, stock: 20, isAvailable: true),
    Product(id: "prod_choco_hazelnut", name: "Choco Hazelnut", category: "Premiums", price: 125, stock: 20, isAvailable: true),
    Product(id: "prod_salted_caramel", name: "Salted Caramel", category: "Premiums", price: 125, stock: 20, isAvailable: true),
    Product(id: "prod_choco_peppermint", name: "Choco Peppermint", category: "Premiums", price: 125, stock: 20, isAvailable: true),
    Product(id: "prod_butterscotch_premium", name: "Butterscotch", category: "Premiums", price: 135, stock: 20, isAvailable: true),
    
    // Non-Coffee
    Product(id: "prod_mango_milk", name: "Mango Milk", category: "Non-Coffee", price: 109, stock: 20, isAvailable: true),
    Product(id: "prod_blueberry_milk", name: "Blueberry Milk", category: "Non-Coffee", price: 109, stock: 20, isAvailable: true),
    Product(id: "prod_mixed_berries_milk", name: "Mixed Berries Milk", category: "Non-Coffee", price: 109, stock: 20, isAvailable: true),
    Product(id: "prod_ube_oatmilk", name: "Ube Oatmilk", category: "Non-Coffee", price: 109, stock: 20, isAvailable: true),
    Product(id: "prod_butterscotch_noncoffee", name: "Butterscotch", category: "Non-Coffee", price: 109, stock: 20, isAvailable: true),
    Product(id: "prod_cookies_n_cream", name: "Cookies N' Cream", category: "Non-Coffee", price: 109, stock: 20, isAvailable: true),
    Product(id: "prod_strawberry_matcha", name: "Strawberry Matcha", category: "Non-Coffee", price: 119, stock: 20, isAvailable: true),
    Product(id: "prod_choco_matcha", name: "Choco Matcha", category: "Non-Coffee", price: 119, stock: 20, isAvailable: true),
    Product(id: "prod_strawberry_creme_brulee", name: "Strawberry Creme Brulee", category: "Non-Coffee", price: 150, stock: 20, isAvailable: true),
    Product(id: "prod_iced_chocolate", name: "Iced Chocolate", category: "Non-Coffee", price: 109, stock: 20, isAvailable: true),
    Product(id: "prod_biscoff", name: "Biscoff", category: "Non-Coffee", price: 150, stock: 20, isAvailable: true),
    
    // Sugar-Free Fizzy Drinks
    Product(id: "prod_watermelon_lemonade", name: "Watermelon Lemonade", category: "Sugar-Free Fizzy Drinks", price: 109, stock: 20, isAvailable: true),
    Product(id: "prod_blue_ocean_breeze", name: "Blue Ocean Breeze", category: "Sugar-Free Fizzy Drinks", price: 109, stock: 20, isAvailable: true),
    Product(id: "prod_chillin_berry_limeade", name: "Chillin Berry Limeade", category: "Sugar-Free Fizzy Drinks", price: 109, stock: 20, isAvailable: true),
    Product(id: "prod_purple_berry_wave", name: "Purple Berry Wave", category: "Sugar-Free Fizzy Drinks", price: 109, stock: 20, isAvailable: true),
    Product(id: "prod_pineapple_mango", name: "Pineapple Mango", category: "Sugar-Free Fizzy Drinks", price: 109, stock: 20, isAvailable: true),
    
    // Add-ons
    Product(id: "prod_espresso_shot", name: "Espresso Shot", category: "Add-ons", price: 25, stock: 20, isAvailable: true),
    Product(id: "prod_oatmilk_addon", name: "Oatmilk", category: "Add-ons", price: 50, stock: 20, isAvailable: true),
    Product(id: "prod_syrup", name: "Syrup", category: "Add-ons", price: 25, stock: 20, isAvailable: true),
    Product(id: "prod_sauce", name: "Sauce", category: "Add-ons", price: 20, stock: 20, isAvailable: true),
  ];

  final batch = db.batch();
  for (final p in products) {
    final ref = db.collection('products').doc(p.id);
    batch.set(ref, p.toFirestore(), SetOptions(merge: true));
  }
  await batch.commit();
  debugPrint('Added ${products.length} products to Firestore');
}

/// Populates master ingredients, standard add-ons, and menu recipes matching
/// the Cafeana Data Overview (Financial & Inventory Report).
Future<void> seedMasterInventoryAndRecipes() async {
  final db = FirebaseFirestore.instance;
  debugPrint('Seeding Master Inventory, Recipes, and Standard Add-ons...');

  // 1. Key Inventory Holdings (Page 3) & Core Recipe Ingredients
  final ingredients = [
    // Top holdings by value from report
    const Ingredient(id: 'ING050', name: 'Matcha Powder', category: 'Powder', packSize: '500 g pack', unit: 'g', unitCost: 3.60, stockLevel: 1000, minStockLevel: 400),
    const Ingredient(id: 'ING042', name: 'White Mocha Sauce', category: 'Sauce', packSize: '1.9 kg bottle', unit: 'g', unitCost: 0.68, stockLevel: 3800, minStockLevel: 1000),
    const Ingredient(id: 'ING041', name: 'Mocha Sauce', category: 'Sauce', packSize: '1.9 kg bottle', unit: 'g', unitCost: 0.58, stockLevel: 3800, minStockLevel: 1000),
    const Ingredient(id: 'ING001', name: 'Espresso Beans (House)', category: 'Coffee', packSize: '1 kg bag', unit: 'g', unitCost: 0.90, stockLevel: 2000, minStockLevel: 1000),
    const Ingredient(id: 'ING040', name: 'Chocolate Sauce', category: 'Sauce', packSize: '2 kg bottle', unit: 'g', unitCost: 0.45, stockLevel: 4000, minStockLevel: 1000),
    const Ingredient(id: 'ING043', name: 'Caramel Sauce', category: 'Sauce', packSize: '2 kg bottle', unit: 'g', unitCost: 0.45, stockLevel: 4000, minStockLevel: 1000),
    const Ingredient(id: 'ING062', name: 'Blueberry Puree', category: 'Fruit', packSize: '1 L pack', unit: 'ml', unitCost: 0.60, stockLevel: 2000, minStockLevel: 800),
    const Ingredient(id: 'ING063', name: 'Mixed Berries Puree', category: 'Fruit', packSize: '1 L pack', unit: 'ml', unitCost: 0.60, stockLevel: 2000, minStockLevel: 800),
    const Ingredient(id: 'ING052', name: 'Cookies N\' Cream Powder', category: 'Powder', packSize: '1 kg pack', unit: 'g', unitCost: 0.55, stockLevel: 2000, minStockLevel: 800),
    const Ingredient(id: 'ING060', name: 'Strawberry Puree', category: 'Fruit', packSize: '1 L pack', unit: 'ml', unitCost: 0.55, stockLevel: 2000, minStockLevel: 800),
    const Ingredient(id: 'ING061', name: 'Mango Puree', category: 'Fruit', packSize: '1 L pack', unit: 'ml', unitCost: 0.50, stockLevel: 2000, minStockLevel: 800),
    const Ingredient(id: 'ING020', name: 'Vanilla Syrup (Avg)', category: 'Syrup', packSize: '750 ml bottle', unit: 'ml', unitCost: 0.60, stockLevel: 1500, minStockLevel: 500),

    // Essential ingredients from Standard Operating Recipes (Page 4)
    const Ingredient(id: 'ING010', name: 'Fresh Milk', category: 'Dairy', packSize: '1 L carton', unit: 'ml', unitCost: 0.12, stockLevel: 20000, minStockLevel: 5000),
    const Ingredient(id: 'ING011', name: 'Condensed Milk', category: 'Dairy', packSize: '1 kg can', unit: 'g', unitCost: 0.158, stockLevel: 6000, minStockLevel: 1500),
    const Ingredient(id: 'ING012', name: 'Oat Milk', category: 'Dairy', packSize: '1 L carton', unit: 'ml', unitCost: 0.28, stockLevel: 6000, minStockLevel: 1500),
    const Ingredient(id: 'ING021', name: 'Simple Syrup', category: 'Syrup', packSize: '750 ml bottle', unit: 'ml', unitCost: 0.26, stockLevel: 3000, minStockLevel: 500),
    const Ingredient(id: 'ING022', name: 'Muscovado Syrup', category: 'Syrup', packSize: '750 ml bottle', unit: 'ml', unitCost: 0.163, stockLevel: 2250, minStockLevel: 500),
    const Ingredient(id: 'ING023', name: 'Toffee Nut Syrup', category: 'Syrup', packSize: '750 ml bottle', unit: 'ml', unitCost: 0.65, stockLevel: 1500, minStockLevel: 500),
    const Ingredient(id: 'ING024', name: 'Butterscotch Syrup', category: 'Syrup', packSize: '750 ml bottle', unit: 'ml', unitCost: 0.65, stockLevel: 1500, minStockLevel: 500),
    const Ingredient(id: 'ING070', name: 'Biscoff Spread', category: 'Sauce', packSize: '1.6 kg jar', unit: 'g', unitCost: 0.65, stockLevel: 3200, minStockLevel: 800),
    const Ingredient(id: 'ING071', name: 'Biscoff Cookie Crumble', category: 'Powder', packSize: '750 g pack', unit: 'g', unitCost: 0.37, stockLevel: 2250, minStockLevel: 500),
    const Ingredient(id: 'ING030', name: 'Soda Water', category: 'Beverage', packSize: '1.5 L bottle', unit: 'ml', unitCost: 0.035, stockLevel: 9000, minStockLevel: 2000),
    const Ingredient(id: 'ING031', name: 'Lemon Juice', category: 'Fruit', packSize: '1 L bottle', unit: 'ml', unitCost: 0.30, stockLevel: 2000, minStockLevel: 500),
    const Ingredient(id: 'ING053', name: 'Ube Powder', category: 'Powder', packSize: '1 kg pack', unit: 'g', unitCost: 0.75, stockLevel: 2000, minStockLevel: 500),
    const Ingredient(id: 'ING064', name: 'Blue Curacao Syrup', category: 'Syrup', packSize: '750 ml bottle', unit: 'ml', unitCost: 0.55, stockLevel: 1500, minStockLevel: 500),
    const Ingredient(id: 'ING072', name: 'Macadamia Syrup', category: 'Syrup', packSize: '750 ml bottle', unit: 'ml', unitCost: 0.65, stockLevel: 1500, minStockLevel: 500),
    const Ingredient(id: 'ING025', name: 'Hazelnut Syrup', category: 'Syrup', packSize: '750 ml bottle', unit: 'ml', unitCost: 0.65, stockLevel: 1500, minStockLevel: 500),
    const Ingredient(id: 'ING026', name: 'Peppermint Syrup', category: 'Syrup', packSize: '750 ml bottle', unit: 'ml', unitCost: 0.65, stockLevel: 1500, minStockLevel: 500),
    const Ingredient(id: 'ING027', name: 'Watermelon Syrup', category: 'Syrup', packSize: '750 ml bottle', unit: 'ml', unitCost: 0.55, stockLevel: 1500, minStockLevel: 500),
    const Ingredient(id: 'ING028', name: 'Pineapple Syrup', category: 'Syrup', packSize: '750 ml bottle', unit: 'ml', unitCost: 0.55, stockLevel: 1500, minStockLevel: 500),
    const Ingredient(id: 'ING029', name: 'Almond Syrup', category: 'Syrup', packSize: '750 ml bottle', unit: 'ml', unitCost: 0.65, stockLevel: 1500, minStockLevel: 500),
    const Ingredient(id: 'ING080', name: '16 oz Cup + Lid + Straw', category: 'Packaging', packSize: '100 set sleeve', unit: 'set', unitCost: 4.50, stockLevel: 600, minStockLevel: 150),
    const Ingredient(id: 'ING082', name: '12 oz Cup + Lid + Straw', category: 'Packaging', packSize: '100 set sleeve', unit: 'set', unitCost: 4.50, stockLevel: 600, minStockLevel: 150),
    const Ingredient(id: 'ING081', name: 'Ice', category: 'Ice', packSize: '5 kg bag', unit: 'g', unitCost: 0.01875, stockLevel: 20000, minStockLevel: 5000),
  ];

  final ingBatch = db.batch();
  for (final ing in ingredients) {
    ingBatch.set(db.collection('ingredients').doc(ing.id), ing.toFirestore(), SetOptions(merge: true));
  }
  await ingBatch.commit();
  debugPrint('Seeded ${ingredients.length} master ingredients');

  // 2. Standard Add-ons (Page 3)
  final addOns = [
    const StandardAddOn(id: 'ADD_SAUCE', name: 'Sauce (15g)', costedWith: 'Caramel Sauce', cost: 6.75, price: 20.00, ingredientId: 'ING043', portionSize: 15, unit: 'g'),
    const StandardAddOn(id: 'ADD_SYRUP', name: 'Syrup (15ml)', costedWith: 'Vanilla Syrup', cost: 9.00, price: 25.00, ingredientId: 'ING020', portionSize: 15, unit: 'ml'),
    const StandardAddOn(id: 'ADD_ESPRESSO', name: 'Espresso Shot (9g)', costedWith: 'House Blend', cost: 8.10, price: 25.00, ingredientId: 'ING001', portionSize: 9, unit: 'g'),
    const StandardAddOn(id: 'ADD_OATMILK', name: 'Oatmilk Sub (200ml)', costedWith: 'Oat Milk (extra vs fresh)', cost: 33.00, price: 50.00, ingredientId: 'ING012', portionSize: 200, unit: 'ml'),
  ];

  final addOnBatch = db.batch();
  for (final addOn in addOns) {
    addOnBatch.set(db.collection('addOns').doc(addOn.id), addOn.toFirestore(), SetOptions(merge: true));
    // Also save in products collection under category 'Add-ons' for customer customization modal
    addOnBatch.set(
      db.collection('products').doc('addon_${addOn.id.toLowerCase()}'),
      {
        'id': 'addon_${addOn.id.toLowerCase()}',
        'name': addOn.name,
        'price': addOn.price,
        'cost': addOn.cost,
        'category': 'Add-ons',
        'isAvailable': true,
        'isFeatured': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
  await addOnBatch.commit();
  debugPrint('Seeded ${addOns.length} standard add-ons');

  // 3. Precise Menu Products with Recipes (Page 2 & Page 4)
  final menuProducts = [
    // Classics
    const Product(
      id: 'prod_americano',
      itemId: 'M001',
      name: 'Americano',
      category: 'Classics',
      price: 99.00,
      cost: 25.12,
      isAvailable: true,
      stock: 45,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_cafe_latte',
      itemId: 'M002',
      name: 'Cafe Latte',
      category: 'Classics',
      price: 99.00,
      cost: 47.70,
      isAvailable: true,
      stock: 30,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_cappuccino',
      itemId: 'M003',
      name: 'Cappuccino',
      category: 'Classics',
      price: 99.00,
      cost: 46.50,
      isAvailable: true,
      stock: 25,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 190, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_spanish_latte',
      itemId: 'M004',
      name: 'Spanish Latte',
      category: 'Classics',
      price: 119.00,
      cost: 54.85,
      isAvailable: true,
      stock: 35,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING011', name: 'Condensed Milk', quantity: 45, unit: 'g', unitCost: 0.158),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_vanilla',
      itemId: 'M005',
      name: 'Vanilla Latte',
      category: 'Classics',
      price: 119.00,
      cost: 56.70,
      isAvailable: true,
      stock: 25,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING020', name: 'Vanilla Syrup (Avg)', quantity: 30, unit: 'ml', unitCost: 0.60),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_caramel_latte',
      itemId: 'M006',
      name: 'Caramel Latte',
      category: 'Classics',
      price: 119.00,
      cost: 57.50,
      isAvailable: true,
      stock: 25,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING043', name: 'Caramel Sauce', quantity: 30, unit: 'g', unitCost: 0.45),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_french_vanilla',
      itemId: 'M007',
      name: 'French Vanilla',
      category: 'Classics',
      price: 119.00,
      cost: 58.20,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 190, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING020', name: 'Vanilla Syrup (Avg)', quantity: 25, unit: 'ml', unitCost: 0.60),
        RecipeItem(ingredientId: 'ING011', name: 'Condensed Milk', quantity: 25, unit: 'g', unitCost: 0.158),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_hazelnut',
      itemId: 'M008',
      name: 'Hazelnut',
      category: 'Classics',
      price: 119.00,
      cost: 58.50,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING025', name: 'Hazelnut Syrup', quantity: 30, unit: 'ml', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_dirty_matcha',
      itemId: 'M009',
      name: 'Dirty Matcha',
      category: 'Classics',
      price: 119.00,
      cost: 69.30,
      isAvailable: true,
      stock: 18,
      recipe: [
        RecipeItem(ingredientId: 'ING050', name: 'Matcha Powder', quantity: 8, unit: 'g', unitCost: 3.60),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 9, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING021', name: 'Simple Syrup', quantity: 15, unit: 'ml', unitCost: 0.26),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),

    // Specialty / Iced Coffee
    const Product(
      id: 'prod_toffee_nut_latte',
      itemId: 'M010',
      name: 'Toffee Nut Latte',
      category: 'Specialty',
      price: 135.00,
      cost: 65.70,
      isAvailable: true,
      stock: 22,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING023', name: 'Toffee Nut Syrup', quantity: 30, unit: 'ml', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_creme_brulee_latte',
      itemId: 'M011',
      name: 'Creme Brulee Latte',
      category: 'Specialty',
      price: 135.00,
      cost: 66.80,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 180, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING020', name: 'Vanilla Syrup (Avg)', quantity: 20, unit: 'ml', unitCost: 0.60),
        RecipeItem(ingredientId: 'ING043', name: 'Caramel Sauce', quantity: 20, unit: 'g', unitCost: 0.45),
        RecipeItem(ingredientId: 'ING011', name: 'Condensed Milk', quantity: 15, unit: 'g', unitCost: 0.158),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_toasty_almonds_latte',
      itemId: 'M012',
      name: 'Toasty Almonds Latte',
      category: 'Specialty',
      price: 135.00,
      cost: 67.10,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING029', name: 'Almond Syrup', quantity: 30, unit: 'ml', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_chocodamia',
      itemId: 'M013',
      name: 'Chocodamia',
      category: 'Specialty',
      price: 140.00,
      cost: 79.20,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 180, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING040', name: 'Chocolate Sauce', quantity: 30, unit: 'g', unitCost: 0.45),
        RecipeItem(ingredientId: 'ING072', name: 'Macadamia Syrup', quantity: 20, unit: 'ml', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_caradamia_latte',
      itemId: 'M014',
      name: 'Caradamia Latte',
      category: 'Specialty',
      price: 140.00,
      cost: 77.50,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 180, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING072', name: 'Macadamia Syrup', quantity: 20, unit: 'ml', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING043', name: 'Caramel Sauce', quantity: 20, unit: 'g', unitCost: 0.45),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_espresso_katipunero',
      itemId: 'M015',
      name: 'Espresso Katipunero',
      category: 'Specialty',
      price: 148.00,
      cost: 43.00,
      isAvailable: true,
      stock: 25,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 120, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING022', name: 'Muscovado Syrup', quantity: 30, unit: 'ml', unitCost: 0.163),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_biscoff_latte',
      itemId: 'M016',
      name: 'Biscoff Latte',
      category: 'Premiums',
      price: 150.00,
      cost: 79.40,
      isAvailable: true,
      stock: 28,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING070', name: 'Biscoff Spread', quantity: 35, unit: 'g', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING071', name: 'Biscoff Cookie Crumble', quantity: 12, unit: 'g', unitCost: 0.37),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
      recipeSmall: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 9, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 150, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING070', name: 'Biscoff Spread', quantity: 25, unit: 'g', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING071', name: 'Biscoff Cookie Crumble', quantity: 8, unit: 'g', unitCost: 0.37),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 120, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING082', name: '12 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_biscoffee',
      itemId: 'M016',
      name: 'Biscoffee',
      category: 'Premiums',
      price: 150.00,
      cost: 79.40,
      isAvailable: true,
      stock: 28,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING070', name: 'Biscoff Spread', quantity: 35, unit: 'g', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING071', name: 'Biscoff Cookie Crumble', quantity: 12, unit: 'g', unitCost: 0.37),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
      recipeSmall: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 9, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 150, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING070', name: 'Biscoff Spread', quantity: 25, unit: 'g', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING071', name: 'Biscoff Cookie Crumble', quantity: 8, unit: 'g', unitCost: 0.37),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 120, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING082', name: '12 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),

    // Premiums
    const Product(
      id: 'prod_caramel_macchiato',
      itemId: 'M017',
      name: 'Caramel Macchiato',
      category: 'Premiums',
      price: 125.00,
      cost: 72.45,
      isAvailable: true,
      stock: 30,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING020', name: 'Vanilla Syrup (Avg)', quantity: 20, unit: 'ml', unitCost: 0.60),
        RecipeItem(ingredientId: 'ING043', name: 'Caramel Sauce', quantity: 25, unit: 'g', unitCost: 0.45),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_mocha',
      itemId: 'M018',
      name: 'Mocha',
      category: 'Premiums',
      price: 125.00,
      cost: 67.50,
      isAvailable: true,
      stock: 25,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING041', name: 'Mocha Sauce', quantity: 35, unit: 'g', unitCost: 0.58),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_white_mocha',
      itemId: 'M019',
      name: 'White Mocha',
      category: 'Premiums',
      price: 125.00,
      cost: 68.22,
      isAvailable: true,
      stock: 25,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING042', name: 'White Mocha Sauce', quantity: 35, unit: 'g', unitCost: 0.68),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_choco_hazelnut',
      itemId: 'M020',
      name: 'Choco Hazelnut',
      category: 'Premiums',
      price: 125.00,
      cost: 70.10,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 180, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING040', name: 'Chocolate Sauce', quantity: 25, unit: 'g', unitCost: 0.45),
        RecipeItem(ingredientId: 'ING025', name: 'Hazelnut Syrup', quantity: 20, unit: 'ml', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_salted_caramel',
      itemId: 'M021',
      name: 'Salted Caramel',
      category: 'Premiums',
      price: 125.00,
      cost: 69.80,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING043', name: 'Caramel Sauce', quantity: 35, unit: 'g', unitCost: 0.45),
        RecipeItem(ingredientId: 'ING021', name: 'Simple Syrup', quantity: 10, unit: 'ml', unitCost: 0.26),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_choco_peppermint',
      itemId: 'M022',
      name: 'Choco Peppermint',
      category: 'Premiums',
      price: 125.00,
      cost: 71.30,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 180, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING040', name: 'Chocolate Sauce', quantity: 25, unit: 'g', unitCost: 0.45),
        RecipeItem(ingredientId: 'ING026', name: 'Peppermint Syrup', quantity: 20, unit: 'ml', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_butterscotch_premium',
      itemId: 'M023',
      name: 'Butterscotch',
      category: 'Premiums',
      price: 135.00,
      cost: 72.45,
      isAvailable: true,
      stock: 22,
      recipe: [
        RecipeItem(ingredientId: 'ING001', name: 'Espresso Beans (House Blend)', quantity: 18, unit: 'g', unitCost: 0.90),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING024', name: 'Butterscotch Syrup', quantity: 30, unit: 'ml', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING043', name: 'Caramel Sauce', quantity: 15, unit: 'g', unitCost: 0.45),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),

    // Non-Coffee
    const Product(
      id: 'prod_mango_milk',
      itemId: 'M024',
      name: 'Mango Milk',
      category: 'Non-Coffee',
      price: 109.00,
      cost: 61.50,
      isAvailable: true,
      stock: 25,
      recipe: [
        RecipeItem(ingredientId: 'ING061', name: 'Mango Puree', quantity: 60, unit: 'ml', unitCost: 0.50),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING021', name: 'Simple Syrup', quantity: 15, unit: 'ml', unitCost: 0.26),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_matcha',
      itemId: 'M025',
      name: 'Matcha',
      category: 'Non-Coffee',
      price: 109.00,
      cost: 62.10,
      isAvailable: true,
      stock: 15,
      recipe: [
        RecipeItem(ingredientId: 'ING050', name: 'Matcha Powder', quantity: 10, unit: 'g', unitCost: 3.60),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING021', name: 'Simple Syrup', quantity: 20, unit: 'ml', unitCost: 0.26),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_strawberry_milk',
      itemId: 'M026',
      name: 'Strawberry Milk',
      category: 'Non-Coffee',
      price: 109.00,
      cost: 64.50,
      isAvailable: true,
      stock: 28,
      recipe: [
        RecipeItem(ingredientId: 'ING060', name: 'Strawberry Puree', quantity: 60, unit: 'ml', unitCost: 0.55),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING021', name: 'Simple Syrup', quantity: 15, unit: 'ml', unitCost: 0.26),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_blueberry_milk',
      itemId: 'M027',
      name: 'Blueberry Milk',
      category: 'Non-Coffee',
      price: 109.00,
      cost: 65.20,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING062', name: 'Blueberry Puree', quantity: 60, unit: 'ml', unitCost: 0.60),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING021', name: 'Simple Syrup', quantity: 15, unit: 'ml', unitCost: 0.26),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_mixed_berries_milk',
      itemId: 'M028',
      name: 'Mixed Berries Milk',
      category: 'Non-Coffee',
      price: 109.00,
      cost: 65.20,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING063', name: 'Mixed Berries Puree', quantity: 60, unit: 'ml', unitCost: 0.60),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING021', name: 'Simple Syrup', quantity: 15, unit: 'ml', unitCost: 0.26),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_butterscotch_noncoffee',
      itemId: 'M029',
      name: 'Butterscotch Milk',
      category: 'Non-Coffee',
      price: 109.00,
      cost: 63.80,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING024', name: 'Butterscotch Syrup', quantity: 30, unit: 'ml', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING043', name: 'Caramel Sauce', quantity: 15, unit: 'g', unitCost: 0.45),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_ube_oatmilk',
      itemId: 'M030',
      name: 'Ube Oatmilk',
      category: 'Non-Coffee',
      price: 109.00,
      cost: 93.30,
      isAvailable: true,
      stock: 16,
      recipe: [
        RecipeItem(ingredientId: 'ING053', name: 'Ube Powder', quantity: 30, unit: 'g', unitCost: 0.75),
        RecipeItem(ingredientId: 'ING012', name: 'Oat Milk', quantity: 200, unit: 'ml', unitCost: 0.28),
        RecipeItem(ingredientId: 'ING011', name: 'Condensed Milk', quantity: 30, unit: 'g', unitCost: 0.158),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_cookies_n_cream',
      itemId: 'M031',
      name: 'Cookies N\' Cream',
      category: 'Non-Coffee',
      price: 109.00,
      cost: 59.80,
      isAvailable: true,
      stock: 24,
      recipe: [
        RecipeItem(ingredientId: 'ING052', name: 'Cookies N\' Cream Powder', quantity: 35, unit: 'g', unitCost: 0.55),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 180, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING011', name: 'Condensed Milk', quantity: 30, unit: 'g', unitCost: 0.158),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_strawberry_matcha',
      itemId: 'M032',
      name: 'Strawberry Matcha',
      category: 'Non-Coffee',
      price: 119.00,
      cost: 71.40,
      isAvailable: true,
      stock: 18,
      recipe: [
        RecipeItem(ingredientId: 'ING050', name: 'Matcha Powder', quantity: 8, unit: 'g', unitCost: 3.60),
        RecipeItem(ingredientId: 'ING060', name: 'Strawberry Puree', quantity: 45, unit: 'ml', unitCost: 0.55),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 180, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING021', name: 'Simple Syrup', quantity: 10, unit: 'ml', unitCost: 0.26),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_choco_matcha',
      itemId: 'M033',
      name: 'Choco Matcha',
      category: 'Non-Coffee',
      price: 119.00,
      cost: 72.80,
      isAvailable: true,
      stock: 18,
      recipe: [
        RecipeItem(ingredientId: 'ING050', name: 'Matcha Powder', quantity: 8, unit: 'g', unitCost: 3.60),
        RecipeItem(ingredientId: 'ING040', name: 'Chocolate Sauce', quantity: 30, unit: 'g', unitCost: 0.45),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 180, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_iced_chocolate',
      itemId: 'M034',
      name: 'Iced Chocolate',
      category: 'Non-Coffee',
      price: 109.00,
      cost: 58.90,
      isAvailable: true,
      stock: 25,
      recipe: [
        RecipeItem(ingredientId: 'ING040', name: 'Chocolate Sauce', quantity: 40, unit: 'g', unitCost: 0.45),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING011', name: 'Condensed Milk', quantity: 20, unit: 'g', unitCost: 0.158),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_strawberry_creme_brulee',
      itemId: 'M035',
      name: 'Strawberry Creme Brulee',
      category: 'Non-Coffee',
      price: 150.00,
      cost: 78.50,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING060', name: 'Strawberry Puree', quantity: 40, unit: 'ml', unitCost: 0.55),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 180, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING020', name: 'Vanilla Syrup (Avg)', quantity: 15, unit: 'ml', unitCost: 0.60),
        RecipeItem(ingredientId: 'ING043', name: 'Caramel Sauce', quantity: 20, unit: 'g', unitCost: 0.45),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_biscoff',
      itemId: 'M036',
      name: 'Biscoff',
      category: 'Non-Coffee',
      price: 150.00,
      cost: 77.80,
      isAvailable: true,
      stock: 20,
      recipe: [
        RecipeItem(ingredientId: 'ING070', name: 'Biscoff Spread', quantity: 35, unit: 'g', unitCost: 0.65),
        RecipeItem(ingredientId: 'ING071', name: 'Biscoff Cookie Crumble', quantity: 12, unit: 'g', unitCost: 0.37),
        RecipeItem(ingredientId: 'ING010', name: 'Fresh Milk', quantity: 200, unit: 'ml', unitCost: 0.12),
        RecipeItem(ingredientId: 'ING011', name: 'Condensed Milk', quantity: 20, unit: 'g', unitCost: 0.158),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),

    // Fizzy Drinks
    const Product(
      id: 'prod_watermelon_lemonade',
      itemId: 'M037',
      name: 'Watermelon Lemonade',
      category: 'Fizzy Drinks',
      price: 109.00,
      cost: 52.80,
      isAvailable: true,
      stock: 30,
      recipe: [
        RecipeItem(ingredientId: 'ING027', name: 'Watermelon Syrup', quantity: 45, unit: 'ml', unitCost: 0.55),
        RecipeItem(ingredientId: 'ING031', name: 'Lemon Juice', quantity: 30, unit: 'ml', unitCost: 0.30),
        RecipeItem(ingredientId: 'ING021', name: 'Simple Syrup', quantity: 20, unit: 'ml', unitCost: 0.26),
        RecipeItem(ingredientId: 'ING030', name: 'Soda Water', quantity: 160, unit: 'ml', unitCost: 0.035),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_strawberry_lemonade',
      itemId: 'M038',
      name: 'Strawberry Lemonade',
      category: 'Fizzy Drinks',
      price: 109.00,
      cost: 54.17,
      isAvailable: true,
      stock: 35,
      recipe: [
        RecipeItem(ingredientId: 'ING060', name: 'Strawberry Puree', quantity: 60, unit: 'ml', unitCost: 0.55),
        RecipeItem(ingredientId: 'ING031', name: 'Lemon Juice', quantity: 30, unit: 'ml', unitCost: 0.30),
        RecipeItem(ingredientId: 'ING021', name: 'Simple Syrup', quantity: 30, unit: 'ml', unitCost: 0.26),
        RecipeItem(ingredientId: 'ING030', name: 'Soda Water', quantity: 160, unit: 'ml', unitCost: 0.035),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_chillin_berry_limeade',
      itemId: 'M039',
      name: 'Chillin Berry Limeade',
      category: 'Fizzy Drinks',
      price: 109.00,
      cost: 53.60,
      isAvailable: true,
      stock: 30,
      recipe: [
        RecipeItem(ingredientId: 'ING063', name: 'Mixed Berries Puree', quantity: 50, unit: 'ml', unitCost: 0.60),
        RecipeItem(ingredientId: 'ING031', name: 'Lemon Juice', quantity: 30, unit: 'ml', unitCost: 0.30),
        RecipeItem(ingredientId: 'ING021', name: 'Simple Syrup', quantity: 20, unit: 'ml', unitCost: 0.26),
        RecipeItem(ingredientId: 'ING030', name: 'Soda Water', quantity: 160, unit: 'ml', unitCost: 0.035),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_blue_ocean_breeze',
      itemId: 'M040',
      name: 'Blue Ocean Breeze',
      category: 'Fizzy Drinks',
      price: 109.00,
      cost: 37.37,
      isAvailable: true,
      stock: 32,
      recipe: [
        RecipeItem(ingredientId: 'ING064', name: 'Blue Curacao Syrup', quantity: 30, unit: 'ml', unitCost: 0.55),
        RecipeItem(ingredientId: 'ING031', name: 'Lemon Juice', quantity: 20, unit: 'ml', unitCost: 0.30),
        RecipeItem(ingredientId: 'ING030', name: 'Soda Water', quantity: 180, unit: 'ml', unitCost: 0.035),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_purple_berry_wave',
      itemId: 'M041',
      name: 'Purple Berry Wave',
      category: 'Fizzy Drinks',
      price: 109.00,
      cost: 54.00,
      isAvailable: true,
      stock: 25,
      recipe: [
        RecipeItem(ingredientId: 'ING062', name: 'Blueberry Puree', quantity: 40, unit: 'ml', unitCost: 0.60),
        RecipeItem(ingredientId: 'ING064', name: 'Blue Curacao Syrup', quantity: 20, unit: 'ml', unitCost: 0.55),
        RecipeItem(ingredientId: 'ING031', name: 'Lemon Juice', quantity: 20, unit: 'ml', unitCost: 0.30),
        RecipeItem(ingredientId: 'ING030', name: 'Soda Water', quantity: 180, unit: 'ml', unitCost: 0.035),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
    const Product(
      id: 'prod_pineapple_mango',
      itemId: 'M042',
      name: 'Pineapple Mango',
      category: 'Fizzy Drinks',
      price: 109.00,
      cost: 51.50,
      isAvailable: true,
      stock: 25,
      recipe: [
        RecipeItem(ingredientId: 'ING028', name: 'Pineapple Syrup', quantity: 30, unit: 'ml', unitCost: 0.55),
        RecipeItem(ingredientId: 'ING061', name: 'Mango Puree', quantity: 30, unit: 'ml', unitCost: 0.50),
        RecipeItem(ingredientId: 'ING030', name: 'Soda Water', quantity: 180, unit: 'ml', unitCost: 0.035),
        RecipeItem(ingredientId: 'ING081', name: 'Ice', quantity: 160, unit: 'g', unitCost: 0.01875),
        RecipeItem(ingredientId: 'ING080', name: '16 oz Cup + Lid + Straw', quantity: 1, unit: 'set', unitCost: 4.50),
      ],
    ),
  ];

  final prodBatch = db.batch();
  final Map<String, Product> productByItemId = {};
  final Map<String, Product> productByName = {};
  final Map<String, Product> productByNormalizedName = {};

  String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  for (final p in menuProducts) {
    // Store an explicit Small (12 oz) build alongside the Large (16 oz) one.
    final withSizes = p.recipe.isNotEmpty && p.recipeSmall.isEmpty
        ? p.copyWith(recipeSmall: Product.autoScaleSmall(p.recipe))
        : p;
    prodBatch.set(db.collection('products').doc(p.id), withSizes.toFirestore(), SetOptions(merge: true));

    if (p.itemId != null) {
      productByItemId[p.itemId!.trim().toUpperCase()] = withSizes;
    }
    productByName[p.name.trim().toLowerCase()] = withSizes;
    productByNormalizedName[normalize(p.name)] = withSizes;
  }
  await prodBatch.commit();
  debugPrint('Seeded ${menuProducts.length} standard menu items with Small/Large recipes');

  // Register common aliases for historical or alternative product names
  void addAlias(String alias, String itemId) {
    final target = menuProducts.cast<Product?>().firstWhere(
          (p) => p?.itemId == itemId,
          orElse: () => null,
        );
    if (target != null) {
      productByName[alias.trim().toLowerCase()] = target;
      productByNormalizedName[normalize(alias)] = target;
    }
  }

  addAlias('Biscoff Latte', 'M016');
  addAlias('Vanilla', 'M005');
  addAlias('Caramel', 'M006');
  addAlias('Hazelnut Latte', 'M008');
  addAlias('Katipunero', 'M015');
  addAlias('Ices Chocolate', 'M034');
  addAlias('Ube Oat Milk', 'M030');

  // Also backfill any existing products in Firestore that currently have empty recipes
  try {
    final existingSnapshot = await db.collection('products').get();
    final updateBatch = db.batch();
    int updatedCount = 0;

    for (final doc in existingSnapshot.docs) {
      final data = doc.data();
      final List existingRecipe = (data['recipe'] as List?) ?? [];
      final List existingRecipeSmall = (data['recipeSmall'] as List?) ?? [];
      final String? existingItemId = data['itemId'] as String?;
      final String existingName = (data['name'] as String? ?? '').trim().toLowerCase();
      final bool isBiscoff = existingName.contains('biscoff') || doc.id.toLowerCase().contains('biscoff');

      if (existingRecipe.isEmpty || existingRecipeSmall.isEmpty || isBiscoff) {
        Product? matched = existingItemId != null ? productByItemId[existingItemId.trim().toUpperCase()] : null;
        matched ??= productByName[existingName];
        matched ??= productByNormalizedName[normalize(existingName)];

        if (matched == null && isBiscoff) {
          matched = productByItemId['M016'] ??
              menuProducts.cast<Product?>().firstWhere((p) => p?.itemId == 'M016', orElse: () => null);
        }

        if (matched != null && matched.recipe.isNotEmpty) {
          final effectiveSmall = matched.recipeSmall.isNotEmpty
              ? matched.recipeSmall
              : Product.autoScaleSmall(matched.recipe);
          updateBatch.update(doc.reference, {
            'recipe': matched.recipe.map((r) => r.toMap()).toList(),
            'recipeSmall': effectiveSmall.map((r) => r.toMap()).toList(),
            if (data['cost'] == null || data['cost'] == 0) 'cost': matched.cost,
            if (data['itemId'] == null && matched.itemId != null) 'itemId': matched.itemId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          updatedCount++;
        }
      }
    }
    if (updatedCount > 0) {
      await updateBatch.commit();
      debugPrint('Backfilled $updatedCount existing Firestore products with master recipes.');
    }
  } catch (e) {
    debugPrint('Note: Error backfilling existing product recipes: $e');
  }
}

