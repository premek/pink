VAR health = 8
Monsieur Fogg was looking {describe_health(health)}.

=== function describe_health(x) ===
{
- x == 100:
	~ return "spritely"
- x > 75:
	~ return "chipper"
- x > 45:
	~ return "somewhat flagging"
- else:
	~ return "despondent"
}
