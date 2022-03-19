INSERT INTO garden.plants (label) VALUES
('argugula'), ('artichoke'), ('asparagus'), ('basil'), ('bean'), ('beet'),
('bok choy'), ('broccoli'), ('brussel sprout'), ('cabbage'), ('chamomile'),
('carrot'), ('cauliflower'), ('celery'), ('cilantro'), ('corn'), ('cucumber'),
('dill'), ('eggplant'), ('fennel'), ('garlic'), ('kale'), ('lavender'),
('leek'), ('lentil'), ('lettuce'), ('marjoram'), ('okra'), ('onion'),
('parsley'), ('pea'), ('pepper'), ('potato'), ('pumpkin'), ('quinoa'),
('radicchio'), ('radish'), ('spinach'), ('swiss chard'), ('tomatillo'),
('tomato'), ('zucchini')
ON CONFLICT (label) DO NOTHING;
