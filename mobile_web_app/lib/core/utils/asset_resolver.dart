String? resolveProductAssetImage(String name) {
  final n = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  const mapping = <String, String>{
    'americano': 'assets/images/drinks/Americano.png',
    'biscoff latte': 'assets/images/drinks/Biscoff Latte.png',
    'biscoff': 'assets/images/drinks/Biscoff.png',
    'biscoffee': 'assets/images/drinks/Biscoffee.png',
    'blue ocean breeze': 'assets/images/drinks/Blue Ocean Breeze.png',
    'blueberry milk': 'assets/images/drinks/Blueberry Milk.png',
    'butterscotch': 'assets/images/drinks/Butterscotch.png',
    'cafe latte': 'assets/images/drinks/Cafe Latte.png',
    'cappuccino': 'assets/images/drinks/Cappuccino.png',
    'caradamia latte': 'assets/images/drinks/Caradamia Latte.png',
    'caramel latte': 'assets/images/drinks/Caramel Latte.png',
    'caramel macchiato': 'assets/images/drinks/Caramel Macchiato.png',
    'chillin berry limeade': 'assets/images/drinks/Chillin Berry Limeade.png',
    'choco hazelnut': 'assets/images/drinks/Choco Hazelnut.png',
    'choco matcha': 'assets/images/drinks/Choco Matcha.png',
    'choco peppermint': 'assets/images/drinks/Choco Peppermint.png',
    'chocodamia': 'assets/images/drinks/Chocodamia.png',
    'cookies n cream': 'assets/images/drinks/Cookies N_ Cream.png',
    'creme brulee latte': 'assets/images/drinks/Creme Brulee Latte.png',
    'dirty matcha': 'assets/images/drinks/Dirty Matcha.png',
    'espresso katipunero': 'assets/images/drinks/Espresso Katipunero.png',
    'katipunero': 'assets/images/drinks/Espresso Katipunero.png',
    'french vanilla': 'assets/images/drinks/French Vanilla.png',
    'hazelnut': 'assets/images/drinks/Hazelnut.png',
    'ices chocolate': 'assets/images/drinks/Ices Chocolate.png',
    'iced chocolate': 'assets/images/drinks/Ices Chocolate.png',
    'mango milk': 'assets/images/drinks/Mango Milk.png',
    'matcha': 'assets/images/drinks/Matcha.png',
    'mixed berries milk': 'assets/images/drinks/Mixed Berries Milk.png',
    'mocha': 'assets/images/drinks/Mocha.png',
    'pineapple mango': 'assets/images/drinks/Pineapple Mango.png',
    'purple berry wave': 'assets/images/drinks/Purple Berry Wave.png',
    'salted caramel': 'assets/images/drinks/Salted Caramel.png',
    'spanish latte': 'assets/images/drinks/Spanish Latte.png',
    'strawberry creme brulee': 'assets/images/drinks/Strawberry Creme Brulee.png',
    'strawberry lemonade': 'assets/images/drinks/Strawberry Lemonade.png',
    'strawberry matcha': 'assets/images/drinks/Strawberry Matcha.png',
    'strawberry milk': 'assets/images/drinks/Strawberry Milk.png',
    'toasty almonds latte': 'assets/images/drinks/Toasty Almonds Latte.png',
    'toffee nut latte': 'assets/images/drinks/Toffee Nut Latte.png',
    'ube oatmilk': 'assets/images/drinks/Ube OatMilk.png',
    'vanilla': 'assets/images/drinks/Vanilla.png',
    'watermelon lemonade': 'assets/images/drinks/Watermelon Lemonade.png',
    'white mocha': 'assets/images/drinks/White Mocha.png',
  };
  
  for (final entry in mapping.entries) {
    if (n.contains(entry.key)) return entry.value;
  }
  return null;
}
