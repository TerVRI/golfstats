-- Seed data: Popular golf courses for initial database
-- These are well-known courses with their basic info

INSERT INTO public.courses (name, city, state, country, course_rating, slope_rating, par, latitude, longitude, phone, website)
VALUES
-- US Iconic Courses
('Pebble Beach Golf Links', 'Pebble Beach', 'CA', 'USA', 72.8, 145, 72, 36.5684, -121.9511, '(831) 622-8723', 'https://www.pebblebeach.com'),
('Augusta National Golf Club', 'Augusta', 'GA', 'USA', 76.2, 148, 72, 33.5032, -82.0218, NULL, NULL),
('Pinehurst No. 2', 'Pinehurst', 'NC', 'USA', 75.5, 143, 72, 35.1873, -79.4672, '(855) 235-8507', 'https://www.pinehurst.com'),
('TPC Sawgrass (Stadium)', 'Ponte Vedra Beach', 'FL', 'USA', 74.7, 147, 72, 30.1977, -81.3987, '(904) 273-3235', 'https://tpc.com/sawgrass'),
('Whistling Straits (Straits)', 'Kohler', 'WI', 'USA', 76.7, 151, 72, 43.8562, -87.7182, '(800) 618-5535', 'https://www.americanclubresort.com'),
('Torrey Pines (South)', 'La Jolla', 'CA', 'USA', 75.8, 143, 72, 32.9001, -117.2495, '(858) 452-3226', 'https://www.torreypinesgolfcourse.com'),
('Bethpage Black', 'Farmingdale', 'NY', 'USA', 77.5, 155, 71, 40.7459, -73.4517, '(516) 249-0700', 'https://parks.ny.gov/golf-courses/11'),
('Kiawah Island (Ocean)', 'Kiawah Island', 'SC', 'USA', 77.0, 152, 72, 32.5963, -80.0793, '(843) 768-2121', 'https://kiawahresort.com'),
('Spyglass Hill', 'Pebble Beach', 'CA', 'USA', 75.3, 147, 72, 36.5854, -121.9494, '(831) 625-8563', 'https://www.pebblebeach.com'),
('Bandon Dunes', 'Bandon', 'OR', 'USA', 74.5, 138, 72, 43.1828, -124.3943, '(888) 345-6008', 'https://www.bandondunesgolf.com'),

-- UK & Ireland
('St Andrews (Old Course)', 'St Andrews', 'Fife', 'Scotland', 73.1, 132, 72, 56.3432, -2.8024, '+44 1334 466666', 'https://www.standrews.com'),
('Royal County Down', 'Newcastle', 'Down', 'Northern Ireland', 74.0, 142, 71, 54.2166, -5.8789, '+44 28 4372 3314', 'https://www.royalcountydown.org'),
('Royal Portrush (Dunluce)', 'Portrush', 'Antrim', 'Northern Ireland', 73.9, 145, 72, 55.2071, -6.6614, '+44 28 7082 2311', 'https://www.royalportrushgolfclub.com'),
('Turnberry (Ailsa)', 'Turnberry', 'Ayrshire', 'Scotland', 73.2, 137, 70, 55.3208, -4.8317, '+44 1655 331000', 'https://www.turnberry.co.uk'),
('Carnoustie (Championship)', 'Carnoustie', 'Angus', 'Scotland', 75.2, 144, 72, 56.5017, -2.7018, '+44 1241 802270', 'https://www.carnoustiegolflinks.com'),
('Royal Birkdale', 'Southport', 'Merseyside', 'England', 74.2, 142, 72, 53.6277, -3.0246, '+44 1704 552020', 'https://www.royalbirkdale.com'),

-- Australia & Asia Pacific
('Royal Melbourne (West)', 'Melbourne', 'VIC', 'Australia', 74.5, 140, 72, -37.9186, 145.0283, '+61 3 9808 7000', 'https://www.royalmelbourne.com.au'),
('Kauri Cliffs', 'Matauri Bay', 'Northland', 'New Zealand', 73.8, 138, 72, -34.9833, 173.8833, '+64 9 407 0010', 'https://robertsonlodges.com/the-lodges/kauri-cliffs'),
('Cape Kidnappers', 'Hawkes Bay', 'Hawkes Bay', 'New Zealand', 74.2, 140, 71, -39.5167, 177.0833, '+64 6 875 1900', 'https://robertsonlodges.com/the-lodges/the-farm-at-cape-kidnappers'),

-- Other Notable
('Casa de Campo (Teeth of Dog)', 'La Romana', NULL, 'Dominican Republic', 74.8, 145, 72, 18.4138, -68.9706, '+1 809 523 3333', 'https://www.casadecampo.com.do'),
('Cabo del Sol (Ocean)', 'Los Cabos', 'Baja California', 'Mexico', 73.5, 140, 72, 22.9500, -109.8833, '+52 624 145 8200', 'https://cabodelsol.com'),
('Valderrama', 'Sotogrande', 'Andalusia', 'Spain', 74.0, 143, 71, 36.2833, -5.3167, '+34 956 791 200', 'https://www.valderrama.com'),
('Emirates Golf Club (Majlis)', 'Dubai', NULL, 'UAE', 73.5, 139, 72, 25.0983, 55.1667, '+971 4 380 1234', 'https://www.dubaigolf.com'),

-- Popular Public US Courses
('Bethpage Red', 'Farmingdale', 'NY', 'USA', 73.5, 135, 71, 40.7450, -73.4500, '(516) 249-0700', 'https://parks.ny.gov/golf-courses/11'),
('Chambers Bay', 'University Place', 'WA', 'USA', 75.5, 146, 72, 47.1986, -122.5731, '(253) 460-4653', 'https://www.chambersbaygolf.com'),
('Pacific Dunes', 'Bandon', 'OR', 'USA', 73.0, 138, 71, 43.1813, -124.3947, '(888) 345-6008', 'https://www.bandondunesgolf.com'),
('Shadow Creek', 'North Las Vegas', 'NV', 'USA', 74.2, 143, 72, 36.2483, -115.0975, '(866) 260-0069', 'https://www.shadowcreek.com'),
('Sand Valley (Sand Valley)', 'Nekoosa', 'WI', 'USA', 74.3, 139, 72, 44.1500, -89.8833, '(888) 651-5539', 'https://sandvalley.com'),
('Streamsong (Red)', 'Bowling Green', 'FL', 'USA', 73.8, 140, 72, 27.6069, -81.6156, '(863) 428-1000', 'https://www.streamsongresort.com')

ON CONFLICT (name) DO UPDATE SET
  city = EXCLUDED.city,
  state = EXCLUDED.state,
  country = EXCLUDED.country,
  course_rating = EXCLUDED.course_rating,
  slope_rating = EXCLUDED.slope_rating,
  par = EXCLUDED.par,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  phone = EXCLUDED.phone,
  website = EXCLUDED.website,
  updated_at = NOW();
