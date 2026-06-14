-- Enable UUID extension for secure, unique IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Users Table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL, 
    phone VARCHAR(20),
    rating NUMERIC(2,1) DEFAULT 5.0,
    gender VARCHAR(20) DEFAULT 'Unspecified',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Rides Table
CREATE TABLE rides (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    destination VARCHAR(255) NOT NULL,
    meeting_point VARCHAR(255) NOT NULL,
    creator_id UUID REFERENCES users(id) ON DELETE CASCADE,
    seats_total INTEGER NOT NULL,
    female_only BOOLEAN DEFAULT FALSE,
    seats_available INTEGER NOT NULL,
    status VARCHAR(50) DEFAULT 'active', 
    payment_mode VARCHAR(20) DEFAULT 'Any', -- Added from your backend logic
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Ride Participants Table
CREATE TABLE ride_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id UUID REFERENCES rides(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ride_id, user_id) -- Prevents a user from joining the same ride twice!
);

-- 4. Messages Table 
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id UUID REFERENCES rides(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Notifications Table
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE, 
    ride_id UUID REFERENCES rides(id) ON DELETE CASCADE, -- Added from your backend logic
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    icon_type VARCHAR(50) DEFAULT 'person',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. Blocked Passengers Table (Added from your backend logic)
CREATE TABLE blocked_passengers (
    id SERIAL PRIMARY KEY,
    ride_id UUID REFERENCES rides(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ride_id, user_id)
);