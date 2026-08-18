import json

def load_data(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def analyze_details(file_path):
    data = load_data(file_path)
    hands = data.get("handLogs", [])
    
    for i, hand in enumerate(hands):
        handNo = hand.get("handNo")
        if handNo in [9, 24, 67, 74]:
            print(f"Hand {handNo} moves count: {len(hand.get('moves', []))}")
            if len(hand.get('moves', [])) > 0:
                last_move = hand.get('moves')[-1]
                print(f"  Last move action: {last_move.get('action')}, player: {last_move.get('player')}")
                
        # Let's check for "Danger Card" violations
        moves = hand.get("moves", [])
        hand_counts = {"left": 16, "me": 16, "right": 16}
        initial_hands = {
            "left": hand.get("initialLeft", []),
            "me": hand.get("initialMe", []),
            "right": hand.get("initialRight", [])
        }
        
        current_hands = {
            "left": initial_hands["left"].copy(),
            "me": initial_hands["me"].copy(),
            "right": initial_hands["right"].copy()
        }
        
        for move in moves:
            player = move["player"]
            action = move["action"]
            cards = move.get("cards", [])
            
            next_player = {"left": "me", "me": "right", "right": "left"}[player]
            
            # Record remaining cards
            if action == "play":
                hand_counts[player] -= len(cards)
                for c in cards:
                    if c in current_hands[player]:
                        current_hands[player].remove(c)
            
            # Check danger card
            if hand_counts[next_player] == 1 and action == "play" and len(cards) == 1:
                # the current player played a single. Was it their largest?
                # we need to rank the cards to know.
                pass
                
        # Check for unplayed bombs
        # A bomb in Paodekuai is 4 of a kind, or 3 Aces (depending on rules).
        # Let's count 4 of a kind in current_hands at the end of the game for losers.
        winner = None
        for p in ["left", "me", "right"]:
            if hand.get(f"delta{p.capitalize()}", 0) > 0:
                winner = p
                break
        
        if winner:
            for p in ["left", "me", "right"]:
                if p != winner:
                    # check for 4 of a kind
                    ranks = [c[0] for c in current_hands[p] if len(c) > 0]
                    rank_counts = {}
                    for r in ranks:
                        rank_counts[r] = rank_counts.get(r, 0) + 1
                    
                    bombs_left = [r for r, count in rank_counts.items() if count == 4]
                    if 'A' in rank_counts and rank_counts['A'] == 3: # 3 Aces is a bomb usually
                        bombs_left.append('A')
                        
                    if len(bombs_left) > 0:
                        print(f"Hand {handNo}: Player {p} lost but had unplayed bombs: {bombs_left}. Remaining cards: {len(current_hands[p])} ({current_hands[p]})")

if __name__ == "__main__":
    analyze_details("100-2.txt")
