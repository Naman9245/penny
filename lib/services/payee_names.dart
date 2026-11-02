import 'package:penny/services/merchant_categories.dart';

// What Penny may see of a payee the user typed in, when no SMS said whether
// it's a shop or a person. Only words for things, services and roles people
// pay for, and the shops and brands Penny knows, leave the phone. Any other
// word could be someone's name, so it stays here: "For Cook" goes as "Cook",
// "Gift for Priya" as "Gift", and "Rahul Kumar" only as "Person 1".

/// Everyday words for what people in India pay for, in English and common
/// Hinglish, a few to a line. None is a common first name: words that are,
/// like Pooja or Rakhi, are left out on purpose. Plurals ending in s match
/// too.
const _everydayWords = [
  // Food and drink.
  'food meal lunch dinner breakfast brunch snack tiffin mess canteen dhaba',
  'chai tea coffee juice shake milk doodh curd dahi paneer bread egg maggi',
  'momo samosa pizza burger sandwich biryani thali dosa idli paratha roti',
  'chapati rice dal sabzi sabji vegetable veggie fruit grocery groceries',
  'ration atta oil sugar sweet mithai cake chocolate icecream ice cream chip',
  'biscuit water drink cold beer party treat order delivery',
  // Home, and people paid for a job rather than by name.
  'cook cooking maid kaamwali servant helper driver dhobi laundry ironing',
  'istri cleaning cleaner sweeper plumber electrician carpenter mechanic',
  'repair service servicing watchman security gardener salary wage',
  'cylinder gas lpg electricity bijli light bill wifi internet broadband',
  'recharge mobile phone dth cable maintenance society rent kiraya deposit',
  'pg hostel flat room house home brokerage furniture mattress bedsheet',
  'bucket utensil kitchen',
  // Health and looking after yourself.
  'medicine dawai tablet doctor dentist clinic hospital pharmacy chemist',
  'medical lab checkup physio gym protein creatine whey supplement vitamin',
  'salon haircut barber parlour parlor spa shampoo soap toiletries skincare',
  'cosmetic perfume deo',
  // Getting around.
  'auto rickshaw cab taxi bus metro train flight ticket petrol diesel fuel',
  'toll parking bike scooty puncture travel trip card',
  // Study.
  'fee fees tuition coaching class classes course book notebook stationery',
  'xerox photocopy printout print printing exam college school library',
  'project assignment uniform',
  // Shopping.
  'clothes shirt tshirt jeans shoe sneaker slipper watch bag earphone',
  'headphone charger laptop cover gift shopping',
  // Fun and occasions.
  'movie cinema game gaming outing concert show match subscription',
  'membership birthday wedding diwali holi festival',
  // Money.
  'emi loan insurance premium investment sip saving donation charity temple',
  'mandir church gurudwara mosque masjid fine penalty tax charge charges',
  // Shops in general.
  'shop store mart market bazaar stall centre center corner point general',
  'traders agency agencies enterprises emporium bhandar kendra dukaan dukan',
  'wala wale waala waale restaurant cafe hotel bakery dairy pvt private ltd',
  'limited llp india services technologies solutions pay bank',
];

/// Penny's words, and the shops and brands she knows, as whole words or
/// phrases: "Bharat Petroleum" matches, a person called Bharat doesn't.
final _knownWords = () {
  final words = {
    ...knownShopNames,
    for (final line in _everydayWords) ...line.split(' '),
  };
  // Longest first, so a phrase wins over a word inside it.
  final longestFirst = words.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return RegExp(
    r'\b(?:' + longestFirst.map(RegExp.escape).join('|') + r')s?\b',
    caseSensitive: false,
  );
}();

/// [typed] as Penny may see it: only the words she knows, in the user's own
/// spelling, like "For Cook" → "Cook". Null when none are left: then it may
/// be a person, and goes only as "Person 1, 2…".
String? safePayeeName(String typed) {
  final known = [
    for (final match in _knownWords.allMatches(typed)) match.group(0)!,
  ];
  return known.isEmpty ? null : known.join(' ');
}
