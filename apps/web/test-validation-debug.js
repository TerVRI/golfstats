const { validateCourseData } = require('./src/lib/course-validation.ts');

const holePars = [4, 5, 4, 4, 3, 4, 4, 3, 5, 4, 4, 4, 3, 5, 4, 4, 3, 4];
const courseData = {
  name: 'Pebble Beach Golf Links',
  par: 72,
  holes: 18,
  course_rating: 75.5,
  slope_rating: 145,
  latitude: 36.5725,
  longitude: -121.9486,
  hole_data: holePars.map((par, i) => ({
    hole_number: i + 1,
    par: par,
    yardages: { blue: 380, white: 350 },
    tee_locations: [{ lat: 36.5730, lon: -121.9490 }],
    green_center: { lat: 36.5735, lon: -121.9485 },
  })),
};

const result = validateCourseData(courseData);
console.log('Is Valid:', result.isValid);
console.log('Errors:', result.errors);
console.log('Warnings:', result.warnings);
