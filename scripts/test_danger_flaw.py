import json

def load_data(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def test_danger_flaw(file_path):
    data = load_data(file_path)
    hands = data.get("handLogs", [])
    
    count_flaws = 0
    
    for hand in hands:
        moves = hand.get("moves", [])
        hand_counts = {"left": 16, "me": 16, "right": 16}
        
        for i, move in enumerate(moves):
            player = move["player"]
            action = move["action"]
            cards = move.get("cards", [])
            playType = move.get("chosenPlayType")
            
            next_player = {"left": "me", "me": "right", "right": "left"}[player]
            
            if action == "play":
                # Check situation BEFORE move
                if hand_counts[next_player] == 1 and playType in ["pair", "triple", "consecutivePairs", "straight"]:
                    # Next player has 1 card. Our play is a multi-card type.
                    # We should be playing the smallest possible that beats the top card.
                    # Let's see what they played.
                    pass
                hand_counts[player] -= len(cards)

if __name__ == "__main__":
    test_danger_flaw("100-2.txt")
