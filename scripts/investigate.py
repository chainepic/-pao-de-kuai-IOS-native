import json

def load_data(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def print_hand(handNo):
    data = load_data("100-2.txt")
    for hand in data.get("handLogs", []):
        if hand.get("handNo") == handNo:
            print(f"Hand {handNo}")
            print(f"Deltas: L={hand.get('deltaLeft')} M={hand.get('deltaMe')} R={hand.get('deltaRight')}")
            for m in hand.get("moves", []):
                print(f"  {m['player']} {m['action']} {m.get('cards', [])} - reason: {m.get('reason', '')}")

if __name__ == "__main__":
    print_hand(9)
