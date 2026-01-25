import 'package:barber_sync/models/models.dart';

final mockServices = [
  Service(
    id: 's1',
    name: 'Premium Fade',
    price: 35.0,
    duration: 45,
    imageUrl: 'https://images.unsplash.com/photo-1621605815841-28d9446e3a43?w=800',
  ),
  Service(
    id: 's2',
    name: 'Beard Sculpture',
    price: 25.0,
    duration: 30,
    imageUrl: 'https://images.unsplash.com/photo-1593702288066-620428aff6f0?w=800',
  ),
  Service(
    id: 's3',
    name: 'Royal Shave',
    price: 45.0,
    duration: 40,
    imageUrl: 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
  ),
];

final mockStaff = [
  Staff(
    id: 'st1',
    name: 'David "The Blade" Miller',
    role: 'Master Barber',
    experience: 12,
    rating: 4.9,
    reviewsCount: 842,
    description: 'Specializing in classic cuts and modern fades. Over a decade of perfection.',
    imageUrl: 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=800',
    workPhotos: [
      'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800',
      'https://images.unsplash.com/photo-1593702288066-620428aff6f0?w=800',
    ],
    services: ['s1', 's2', 's3'],
  ),
  Staff(
    id: 'st2',
    name: 'Marcus Chen',
    role: 'Senior Stylist',
    experience: 8,
    rating: 4.8,
    reviewsCount: 567,
    description: 'Expert in contemporary styling and hair texturing. Precision is my language.',
    imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800',
    workPhotos: [
      'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
      'https://images.unsplash.com/photo-1516975080664-ed2fc6a32937?w=800',
    ],
    services: ['s1', 's2'],
  ),
];

final mockShops = [
  BarberShop(
    id: 'sh1',
    name: 'The Gentlemen\'s Quarters',
    address: '42 Wall St, Manhattan, NY',
    description: 'A sanctuary of style for the modern man. Experience the tradition of fine grooming.',
    rating: 4.9,
    reviewsCount: 1240,
    photos: [
      'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800',
      'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
    ],
    coordinates: {'lat': 40.7075, 'lng': -74.0113},
    staff: mockStaff,
    services: mockServices,
  ),
  BarberShop(
    id: 'sh2',
    name: 'Royal Heritage Barbers',
    address: '156 Park Ave, Brooklyn, NY',
    description: 'Where royalty meets precision. Traditional barbering at its finest.',
    rating: 4.8,
    reviewsCount: 890,
    photos: [
      'https://images.unsplash.com/photo-1516975080664-ed2fc6a32937?w=800',
      'https://images.unsplash.com/photo-1593702288066-620428aff6f0?w=800',
    ],
    coordinates: {'lat': 40.6925, 'lng': -73.9741},
    staff: [mockStaff[0]],
    services: [mockServices[0], mockServices[1]],
  ),
];
