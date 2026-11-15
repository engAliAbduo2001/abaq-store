import '../models/perfume.dart';

const perfumeCatalog = <Perfume>[
  Perfume(
    id: 'oud-royale',
    name: 'Oud Royale',
    brand: 'Abaq Atelier',
    category: 'Oud',
    description:
        'A captivating blend of rare Cambodian oud, warm amber, and soft woods. '
        'An unmistakable signature made for evenings that linger.',
    notes: ['Cambodian oud', 'Amber', 'Sandalwood'],
    price: 245,
    imageUrl:
        'https://images.unsplash.com/photo-1594035910387-fea47794261f?auto=format&fit=crop&w=900&q=85',
    badge: 'BESTSELLER',
  ),
  Perfume(
    id: 'desert-rose',
    name: 'Desert Rose',
    brand: 'Abaq Atelier',
    category: 'Oriental',
    description:
        'Velvety Damask rose meets saffron and a smooth, resinous base in a '
        'modern interpretation of an oriental classic.',
    notes: ['Damask rose', 'Saffron', 'Benzoin'],
    price: 195,
    imageUrl:
        'https://images.unsplash.com/photo-1592945403244-b3fbafd7f539?auto=format&fit=crop&w=900&q=85',
    badge: 'NEW',
  ),
  Perfume(
    id: 'maison-noire',
    name: 'Maison Noire',
    brand: 'Maison d’Abaq',
    category: 'French',
    description:
        'An elegant Parisian composition with bright citrus, polished iris, '
        'and a deep, beautifully tailored vetiver finish.',
    notes: ['Bergamot', 'Iris', 'Vetiver'],
    price: 220,
    imageUrl:
        'https://images.unsplash.com/photo-1595425970377-c9703cf48b6d?auto=format&fit=crop&w=900&q=85',
  ),
  Perfume(
    id: 'amber-veil',
    name: 'Amber Veil',
    brand: 'Abaq Atelier',
    category: 'Oriental',
    description:
        'Golden amber and vanilla settle into creamy sandalwood for a warm, '
        'intimate fragrance with remarkable depth.',
    notes: ['Amber', 'Madagascar vanilla', 'Sandalwood'],
    price: 180,
    imageUrl:
        'https://images.unsplash.com/photo-1615634260167-c8cdede054de?auto=format&fit=crop&w=900&q=85',
  ),
  Perfume(
    id: 'oud-serein',
    name: 'Oud Serein',
    brand: 'Abaq Privé',
    category: 'Oud',
    description:
        'A softer, contemplative oud softened by cardamom and cashmere woods, '
        'created for understated everyday luxury.',
    notes: ['Cardamom', 'Oud', 'Cashmere woods'],
    price: 265,
    imageUrl:
        'https://images.unsplash.com/photo-1590736969955-71cc94901144?auto=format&fit=crop&w=900&q=85',
  ),
  Perfume(
    id: 'cote-dor',
    name: 'Côte d’Or',
    brand: 'Maison d’Abaq',
    category: 'French',
    description:
        'A sunlit French garden captured in a bottle: neroli and orange blossom '
        'over a delicate trail of white musk.',
    notes: ['Neroli', 'Orange blossom', 'White musk'],
    price: 210,
    imageUrl:
        'https://images.unsplash.com/photo-1608571423902-eed4a5ad8108?auto=format&fit=crop&w=900&q=85',
    badge: 'LIMITED',
  ),
];

Perfume? perfumeById(String id) {
  for (final perfume in perfumeCatalog) {
    if (perfume.id == id) return perfume;
  }
  return null;
}
