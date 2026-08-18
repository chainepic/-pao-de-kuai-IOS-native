import json
import sys

def parse_log(filepath, start_hand=1, end_hand=20):
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    hand_logs = data.get('handLogs', [])
    
    # Filter by hand range
    target_logs = [log for log in hand_logs if start_hand <= log.get('handNo', 0) <= end_hand]
    
    output = []
    
    for log in target_logs:
        hand_no = log.get('handNo')
        winner = log.get('winner')
        first_player = log.get('firstTurnPlayer')
        output.append(f"\n{'='*50}")
        output.append(f"Hand #{hand_no} | Winner: {winner} | First Turn: {first_player}")
        output.append(f"Initial Me    : {log.get('initialMe', [])}")
        output.append(f"Initial Left  : {log.get('initialLeft', [])}")
        output.append(f"Initial Right : {log.get('initialRight', [])}")
        output.append("-" * 50)
        
        moves = log.get('moves', [])
        for move in moves:
            seq = move.get('seq')
            player = move.get('player')
            action = move.get('action')
            cards = move.get('cards', [])
            reason = move.get('reason')
            chosen_type = move.get('chosenPlayType', 'N/A')
            
            snapshot = move.get('snapshot', {})
            hand_count = snapshot.get('handCount', -1)
            legal_count = snapshot.get('legalActionCount', -1)
            
            if action == 'pass':
                output.append(f"[{seq:03d}] {player:5s} | PASS | (Hand: {hand_count}, Legal: {legal_count}) | Reason: {reason}")
            else:
                output.append(f"[{seq:03d}] {player:5s} | PLAY | {cards} ({chosen_type}) | (Hand: {hand_count}, Legal: {legal_count}) | Reason: {reason}")
                
        output.append("-" * 50)
        output.append(f"Result: Me: {log.get('deltaMe')} (Rem: {log.get('remainMe')}), Left: {log.get('deltaLeft')} (Rem: {log.get('remainLeft')}), Right: {log.get('deltaRight')} (Rem: {log.get('remainRight')})")
        
    return "\n".join(output)

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python extract_logs.py <filepath> <start_hand> <end_hand>")
        sys.exit(1)
        
    filepath = sys.argv[1]
    start = int(sys.argv[2])
    end = int(sys.argv[3])
    
    print(parse_log(filepath, start, end))